import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const migration = name => readFileSync(new URL(`../migrations/${name}.sql`, import.meta.url), 'utf8');
await test('atomic cellar inventory', async t => {
  const db = new PGlite({ extensions: { pgcrypto } });
  t.after(() => db.close());
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    GRANT USAGE ON SCHEMA auth,public TO anon,authenticated;`);
  await db.exec(migration('00000000000000_baseline_base_tables'));
  await db.exec('ALTER TABLE profiles ADD COLUMN deleted_at timestamptz;');
  const privacy = migration('20250801000000_privacy_rls_feed_audit');
  await db.exec(privacy.match(/CREATE POLICY "profiles_select"[\s\S]*?;/)[0]);
  const cellar = migration('20260803000013_cellar_bottles');
  const start = cellar.indexOf('CREATE TABLE');
  await db.exec(cellar.slice(start, cellar.indexOf('-- ─', start)));
  // Supabase's normal grants before the new migration tightens direct writes.
  await db.exec('GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;');
  await db.exec(migration('20260912000000_atomic_cellar_inventory'));

  const owner = '00000000-0000-0000-0000-000000000001';
  const other = '00000000-0000-0000-0000-000000000002';
  const wine = '10000000-0000-0000-0000-000000000001';
  const id = n => `50000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
  await db.exec(`INSERT INTO auth.users VALUES ('${owner}'),('${other}');
    INSERT INTO profiles(id,username) VALUES ('${owner}','owner'),('${other}','other');
    INSERT INTO wines(id,name,producer) VALUES ('${wine}','Fixture wine','Fixture producer');`);
  const asUser = async (user, role = 'authenticated') => {
    await db.exec('RESET ROLE');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[user ?? '']);
    await db.exec(`SET ROLE ${role}`);
  };
  const add = async (request, quantity = 1, vintage = null, location = null, wineId = wine) =>
    (await db.query('SELECT add_cellar_bottles($1,$2,$3,$4,$5) AS result',
      [id(request),wineId,quantity,vintage,location])).rows[0].result;
  const drink = async (request,bottle) => (await db.query('SELECT drink_cellar_bottle($1,$2) AS result',
    [id(request),bottle])).rows[0].result;
  const quantity = async bottle => (await db.query('SELECT quantity FROM cellar_bottles WHERE id=$1',[bottle])).rows[0]?.quantity;
  const receiptCount = async request => Number((await db.query('SELECT count(*) AS n FROM cellar_stock_operations WHERE request_id=$1',[id(request)])).rows[0].n);
  const rejectsCode = (fn,code) => assert.rejects(fn,e => e.code === code);
  let unknown, known;

  await t.test('unknown vintage uses the expression index and additions stack', async () => {
    await asUser(owner);
    const first = await add(1,2,null,' Kitchen rack ');
    unknown = first.bottle_id;
    const next = await add(2,3);
    assert.equal(next.bottle_id, unknown);
    assert.equal(next.quantity,5);
    assert.equal((await db.query('SELECT location FROM cellar_bottles WHERE id=$1',[unknown])).rows[0].location,'Kitchen rack');
  });
  await t.test('known vintages stay separate from unknown and from each other', async () => {
    const first = await add(3,2,2020);
    known = first.bottle_id;
    assert.notEqual(known,unknown);
    assert.equal((await add(4,1,2020)).quantity,3);
    assert.notEqual((await add(5,1,2021)).bottle_id,known);
    assert.equal(await quantity(unknown),5);
  });
  await t.test('replaying an addition returns its receipt without incrementing again', async () => {
    assert.deepEqual(await add(2,3),{bottle_id:unknown,quantity:5});
    assert.equal(await quantity(unknown),5);
    assert.equal(await receiptCount(2),1);
  });
  await t.test('request IDs cannot be reused with different payloads or operations', async () => {
    await rejectsCode(() => add(2,4),'22023');
    await rejectsCode(() => drink(2,unknown),'22023');
    assert.equal(await quantity(unknown),5);
  });
  await t.test('opening decrements atomically and a retried opening does not decrement again', async () => {
    const first = await drink(6,unknown);
    assert.equal(first.quantity,4);
    assert.equal((await drink(7,unknown)).quantity,3);
    assert.deepEqual(await drink(6,unknown),first);
    assert.equal(await quantity(unknown),3);
  });
  await t.test('stock never becomes negative; an unsuccessful request leaves no receipt', async () => {
    const only = await add(8,1,2018);
    assert.equal((await drink(9,only.bottle_id)).quantity,0);
    assert.equal((await drink(9,only.bottle_id)).quantity,0);
    await rejectsCode(() => drink(10,only.bottle_id),'P0002');
    assert.equal(await quantity(only.bottle_id),0);
    assert.equal(await receiptCount(10),0);
    await add(11,1,2018);
    assert.equal((await drink(10,only.bottle_id)).quantity,0);
  });
  await t.test('another account cannot see or consume the owner’s stock or receipts', async () => {
    await asUser(other);
    assert.equal(await quantity(unknown),undefined);
    assert.equal(await receiptCount(2),0);
    await rejectsCode(() => drink(12,unknown),'P0002');
    assert.equal(await receiptCount(12),0);
    const own = await add(2,1);
    assert.notEqual(own.bottle_id,unknown);
    await asUser(owner);
    assert.equal(await quantity(unknown),3);
  });
  await t.test('clients cannot bypass stock RPCs or forge receipts with direct writes', async () => {
    await rejectsCode(() => db.query('UPDATE cellar_bottles SET quantity=99 WHERE id=$1',[unknown]),'42501');
    await rejectsCode(() => db.query('DELETE FROM cellar_bottles WHERE id=$1',[unknown]),'42501');
    await rejectsCode(() => db.query('INSERT INTO cellar_stock_operations(user_id,request_id,request) VALUES($1,$2,$3)',[owner,id(13),'{}']),'42501');
  });
  await t.test('anonymous and deleted accounts cannot mutate stock', async () => {
    await asUser(null,'anon');
    await rejectsCode(() => add(14),'42501');
    await asUser(null);
    await rejectsCode(() => add(14),'42501');
    await db.exec(`RESET ROLE; UPDATE profiles SET deleted_at=now() WHERE id='${owner}';`);
    await asUser(owner);
    assert.equal(await quantity(unknown),undefined);
    await rejectsCode(() => add(14),'42501');
    await db.exec(`RESET ROLE; UPDATE profiles SET deleted_at=NULL WHERE id='${owner}';`);
    await asUser(owner);
  });
  await t.test('invalid input and missing catalog wines cannot leave partial operations', async () => {
    for (const qty of [0,-1,10001,null]) await rejectsCode(() => add(15,qty),'22023');
    for (const year of [1799,2101]) await rejectsCode(() => add(15,1,year),'22023');
    await rejectsCode(() => add(15,1,null,'a'.repeat(201)),'22023');
    await rejectsCode(() => add(15,1,null,null,id(999)),'23503');
    assert.equal(await receiptCount(15),0);
  });
  await t.test('a stock write failure rolls back the receipt; the same request can retry', async () => {
    await db.exec(`RESET ROLE; CREATE FUNCTION fail_write() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN RAISE EXCEPTION 'Injected failure'; END; $$;
      CREATE TRIGGER fail_write BEFORE UPDATE ON cellar_bottles FOR EACH ROW EXECUTE FUNCTION fail_write();`);
    await asUser(owner);
    await rejectsCode(() => add(16,1),'P0001');
    assert.equal(await receiptCount(16),0);
    assert.equal(await quantity(unknown),3);
    await db.exec('RESET ROLE; DROP TRIGGER fail_write ON cellar_bottles;');
    await asUser(owner);
    assert.equal((await add(16,1)).quantity,4);
  });
  await t.test('a receipt write failure rolls back the stock decrement', async () => {
    await db.exec('RESET ROLE; CREATE TRIGGER fail_write BEFORE UPDATE ON cellar_stock_operations FOR EACH ROW EXECUTE FUNCTION fail_write();');
    await asUser(owner);
    await rejectsCode(() => drink(17,unknown),'P0001');
    assert.equal(await quantity(unknown),4);
    assert.equal(await receiptCount(17),0);
    await db.exec('RESET ROLE; DROP TRIGGER fail_write ON cellar_stock_operations;');
    await asUser(owner);
  });
  await t.test('integer overflow is rejected without corrupting stock or a receipt', async () => {
    await db.exec('RESET ROLE');
    await db.query('UPDATE cellar_bottles SET quantity=2147483647 WHERE id=$1',[known]);
    await asUser(owner);
    await rejectsCode(() => add(18,1,2020),'22003');
    assert.equal(await receiptCount(18),0);
    assert.equal(await quantity(known),2147483647);
  });
});
