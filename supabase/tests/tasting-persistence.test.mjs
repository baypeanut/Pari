import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

// Real PostgreSQL execution, no network or production data. The baseline tables,
// historical policies and latest feed definitions below come from the repository.
// Auth/Storage infrastructure is a fixture; pgvector and its triggers are outside
// this suite. All three new migrations run verbatim, not copied implementations.
const migration = name => readFileSync(new URL(`../migrations/${name}.sql`, import.meta.url), 'utf8');
await test('tasting persistence and privacy', async t => {
const db = new PGlite({ extensions: { pgcrypto } });
t.after(() => db.close());
await db.exec(`
  CREATE ROLE anon; CREATE ROLE authenticated;
  CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  CREATE SCHEMA storage;
  CREATE TABLE storage.buckets(id text PRIMARY KEY, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text, name text);
  ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
  CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$ SELECT string_to_array($1, '/') $$;
  GRANT USAGE ON SCHEMA auth, public, storage TO anon, authenticated;
`);
await db.exec(migration('00000000000000_baseline_base_tables'));
const community = migration('20250125000000_community_feed');
await db.exec(community.slice(0, community.indexOf('CREATE OR REPLACE VIEW')));
await db.exec(community.slice(community.indexOf('CREATE TABLE IF NOT EXISTS public.comments_cheers')));
const tastings = migration('20250228000000_tastings');
await db.exec(tastings.slice(0, tastings.indexOf('-- Update feed_with_details')));
const link = migration('20250601000000_activity_feed_tasting_id');
await db.exec(link.slice(0, link.indexOf('-- Recreate view')));
await db.exec(migration('20250702000000_profiles_privacy_visibility'));
await db.exec(`ALTER TABLE profiles ADD COLUMN deleted_at timestamptz;
  ALTER TABLE tastings ADD COLUMN comment text;`);
await db.exec(migration('20260317000000_tastings_visibility'));
const moment = migration('20260318000000_tastings_moment_image');
await db.exec(moment.slice(0, moment.indexOf('-- Feed RPCs')));
await db.exec(migration('20260803000006_tasting_structure'));
const privacy = migration('20250801000000_privacy_rls_feed_audit');
await db.exec(privacy.match(/CREATE OR REPLACE FUNCTION public\.can_view_activity[\s\S]*?\$\$;/)[0]);
for (const name of ['profiles_select', 'tastings_select_privacy', 'activity_feed_select_privacy',
                    'likes_select_privacy', 'comments_select_privacy', 'comments_cheers_select_privacy']) {
  await db.exec(privacy.match(new RegExp(`CREATE POLICY "${name}"[\\s\\S]*?;`))[0]);
}
// Keep earlier permissive policies too: the new restrictive policies must still
// protect content if a deployed environment retains an old public-read policy.
const vintage = migration('20260803000000_tasting_vintage');
await db.exec('BEGIN; ALTER TABLE tastings ADD COLUMN vintage int;');
await db.exec(vintage.slice(vintage.indexOf('DROP VIEW IF EXISTS public.feed_with_details')));
await db.exec(`CREATE FUNCTION public.compute_user_taste_profile(uuid) RETURNS double precision[]
  LANGUAGE sql SECURITY DEFINER AS $$ SELECT ARRAY[1.0]::double precision[] $$;
  GRANT ALL ON ALL TABLES IN SCHEMA public, storage TO authenticated;
  GRANT SELECT ON ALL TABLES IN SCHEMA public, storage TO anon;`);

const owner = '00000000-0000-0000-0000-000000000001';
const friend = '00000000-0000-0000-0000-000000000002';
const stranger = '00000000-0000-0000-0000-000000000003';
const wine = '10000000-0000-0000-0000-000000000001';
const log = '30000000-0000-0000-0000-000000000001';
const photo = `${owner}/moment.jpg`;
const full = { rating: 8, note_tags: ['Cherry'], comment: 'Dinner', visibility: 'friends',
  vintage: 2021, acidity: 1, tannin: 2, body: 3, sweetness: 4, aroma_intensity: 5, finish: 2 };
const cleared = { rating: 7, note_tags: null, comment: null, visibility: 'everyone',
  vintage: null, acidity: null, tannin: null, body: null, sweetness: null, aroma_intensity: null, finish: null };
await db.exec(`INSERT INTO auth.users VALUES ('${owner}'), ('${friend}'), ('${stranger}');
  INSERT INTO profiles(id,username) VALUES ('${owner}','owner'),('${friend}','friend'),('${stranger}','stranger');
  INSERT INTO wines(id,name,producer) VALUES ('${wine}','Test wine','Test producer');
  INSERT INTO follows(follower_id,followed_id) VALUES ('${owner}','${friend}'),('${friend}','${owner}');
  INSERT INTO storage.objects(bucket_id,name) VALUES ('moment_images','${photo}');`);

// One clear legacy pair and one ambiguous pair before migration/backfill.
await db.exec(`INSERT INTO tastings(id,user_id,wine_id,rating,created_at) VALUES
  ('30000000-0000-0000-0000-000000000011','${owner}','${wine}',7,'2020-01-01'),
  ('30000000-0000-0000-0000-000000000012','${owner}','${wine}',7,'2020-02-01'),
  ('30000000-0000-0000-0000-000000000013','${owner}','${wine}',7,'2020-02-01');
  INSERT INTO activity_feed(user_id,wine_id,activity_type,created_at) VALUES
  ('${owner}','${wine}','had_wine','2020-01-01'),('${owner}','${wine}','had_wine','2020-02-01');`);
for (const name of ['20260911000000_atomic_tasting_writes', '20260911000001_tasting_visibility', '20260911000002_private_moment_images']) {
  await db.exec(migration(name));
}
const asUser = async (id, role = 'authenticated') => {
  await db.exec('RESET ROLE');
  await db.query("SELECT set_config('request.jwt.claim.sub', $1, false)", [id ?? '']);
  await db.exec(`SET ROLE ${role}`);
};
const create = async (id = log, payload = full) => (await db.query(
  'SELECT public.create_tasting($1,$2,$3::jsonb,$4,$5) AS result', [id, wine, JSON.stringify(payload), 'search', photo])).rows[0].result;
const edit = async (payload = cleared, id = log) => (await db.query(
  'SELECT public.update_tasting($1,$2::jsonb) AS result', [id, JSON.stringify(payload)])).rows[0].result;
const count = async (table, where = 'true', params = []) => Number((await db.query(
  `SELECT count(*) AS n FROM ${table} WHERE ${where}`, params)).rows[0].n);
const rejectsCode = (fn, code) => assert.rejects(fn, error => error.code === code);

await t.test('legacy backfill links only an unambiguous pair', async () => {
  assert.equal(await count('activity_feed', 'tasting_id IS NOT NULL'), 1);
  await asUser(stranger);
  assert.equal(await count('activity_feed'), 1);
  await asUser(owner);
  assert.equal(await count('activity_feed'), 2);
});

await t.test('create returns all fields; replay creates exactly one tasting and activity', async () => {
  await asUser(owner);
  const first = await create();
  assert.equal(first.visibility, 'friends');
  assert.equal(first.vintage, 2021);
  assert.equal(first.aroma_intensity, 5);
  assert.equal(first.wines.name, 'Test wine');
  assert.deepEqual(await create(), first);
  assert.equal(await count('tastings', 'id=$1', [log]), 1);
  assert.equal(await count('activity_feed', 'tasting_id=$1', [log]), 1);
});

await t.test('friends-only privacy applies to table, both RPCs, view and image metadata', async () => {
  for (const [user, visible] of [[owner, 1], [friend, 1], [stranger, 0]]) {
    await asUser(user);
    assert.equal(await count('tastings', 'id=$1', [log]), visible);
    assert.equal(await count('activity_feed', 'tasting_id=$1', [log]), visible);
    assert.equal(await count('feed_with_details', 'tasting_vintage=2021'), visible);
    assert.equal(await count(`feed_global('${owner}',30,NULL::timestamptz)`, 'tasting_vintage=2021'), visible);
    assert.equal(await count(`feed_following('${owner}',30,NULL::timestamptz)`, 'tasting_vintage=2021'), user === friend ? 1 : 0);
    assert.equal(await count('storage.objects', 'name=$1', [photo]), visible);
  }
});

await t.test('guessing a private ID cannot replay, edit, like or comment on it', async () => {
  await asUser(stranger);
  await rejectsCode(() => create(), '42501');
  await rejectsCode(() => edit(), '42501');
  await db.exec('RESET ROLE');
  const activity = (await db.query('SELECT id FROM activity_feed WHERE tasting_id=$1', [log])).rows[0].id;
  await asUser(stranger);
  await rejectsCode(() => db.query('INSERT INTO likes(user_id,activity_id) VALUES($1,$2)', [stranger,activity]), '42501');
  await rejectsCode(() => db.query('INSERT INTO comments(user_id,activity_id,body) VALUES($1,$2,$3)', [stranger,activity,'hidden']), '42501');
});

await t.test('historical public photo references still require current tasting permission', async () => {
  await db.exec('RESET ROLE');
  await db.query('UPDATE tastings SET moment_image_url=$1 WHERE id=$2',
    [`https://example.supabase.co/storage/v1/object/public/moment_images/${photo}`, log]);
  await asUser(friend);
  assert.equal(await count('storage.objects', 'name=$1', [photo]), 1);
  await asUser(stranger);
  assert.equal(await count('storage.objects', 'name=$1', [photo]), 0);
});

await t.test('removing mutual friendship revokes tasting, interactions and photo access', async () => {
  await db.exec('RESET ROLE');
  const activity = (await db.query('SELECT id FROM activity_feed WHERE tasting_id=$1', [log])).rows[0].id;
  await asUser(friend);
  await db.query('INSERT INTO likes(user_id,activity_id) VALUES($1,$2)', [friend,activity]);
  await db.query('DELETE FROM follows WHERE follower_id=$1 AND followed_id=$2', [friend,owner]);
  assert.equal(await count('tastings', 'id=$1', [log]), 0);
  assert.equal(await count('likes', 'activity_id=$1', [activity]), 0);
  assert.equal(await count('storage.objects', 'name=$1', [photo]), 0);
  await db.query('INSERT INTO follows(follower_id,followed_id) VALUES($1,$2)', [friend,owner]);
});

await t.test('client ownership fields cannot impersonate another account', async () => {
  await asUser(owner);
  const id = '30000000-0000-0000-0000-000000000099';
  const result = await create(id, {...full, user_id: stranger});
  assert.equal(result.user_id, owner);
  await db.query('DELETE FROM tastings WHERE id=$1', [id]);
});

await t.test('deleted profiles cannot publish or expose their old records', async () => {
  await db.exec(`RESET ROLE; UPDATE profiles SET deleted_at=now() WHERE id='${owner}';`);
  await asUser(friend);
  assert.equal(await count('tastings', 'id=$1', [log]), 0);
  assert.equal(await count('activity_feed', 'tasting_id=$1', [log]), 0);
  await asUser(owner);
  await rejectsCode(() => create(), '42501');
  await db.exec(`RESET ROLE; UPDATE profiles SET deleted_at=NULL WHERE id='${owner}';`);
});

await t.test('anonymous users cannot read private content or call write/feed RPCs', async () => {
  await asUser(null, 'anon');
  assert.equal(await count('tastings'), 0);
  assert.equal(await count('storage.objects'), 0);
  await rejectsCode(() => create(), '42501');
  await rejectsCode(() => db.query('SELECT * FROM feed_global($1,30,NULL::timestamptz)', [owner]), '42501');
});

await t.test('editing clears optional answers and updates feed text in the same transaction', async () => {
  await asUser(owner);
  const result = await edit();
  for (const key of Object.keys(cleared).filter(k => cleared[k] === null)) assert.equal(result[key], null, key);
  assert.equal(result.visibility, 'everyone');
  assert.equal((await db.query('SELECT content_text FROM activity_feed WHERE tasting_id=$1',[log])).rows[0].content_text, null);
  await asUser(stranger);
  assert.equal(await count('tastings', 'id=$1', [log]), 1);
  assert.equal(await count('storage.objects', 'name=$1', [photo]), 1);
});

await t.test('profile privacy is an additional restriction; one-way follow is insufficient', async () => {
  await db.exec(`RESET ROLE; UPDATE profiles SET activity_visibility='friends' WHERE id='${owner}';
    INSERT INTO follows(follower_id,followed_id) VALUES ('${stranger}','${owner}');`);
  await asUser(stranger);
  assert.equal(await count('tastings', 'id=$1',[log]), 0);
  assert.equal(await count('storage.objects', 'name=$1',[photo]), 0);
  await asUser(friend);
  assert.equal(await count('tastings', 'id=$1',[log]), 1);
  await db.exec(`RESET ROLE; UPDATE profiles SET activity_visibility='everyone' WHERE id='${owner}';`);
});

await t.test('activity insert failure rolls back tasting insert and the same ID can retry', async () => {
  await db.exec(`RESET ROLE; CREATE FUNCTION fail_activity() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 'Injected activity failure'; END; $$;
    CREATE TRIGGER fail_activity BEFORE INSERT ON activity_feed FOR EACH ROW EXECUTE FUNCTION fail_activity();`);
  await asUser(owner);
  const id = '30000000-0000-0000-0000-000000000002';
  await rejectsCode(() => create(id), 'P0001');
  assert.equal(await count('tastings', 'id=$1', [id]), 0);
  await db.exec('RESET ROLE; DROP TRIGGER fail_activity ON activity_feed;');
  await asUser(owner);
  await create(id);
  assert.equal(await count('activity_feed', 'tasting_id=$1', [id]), 1);
});

await t.test('activity update failure rolls back the tasting edit', async () => {
  await db.exec('RESET ROLE; CREATE TRIGGER fail_activity BEFORE UPDATE ON activity_feed FOR EACH ROW EXECUTE FUNCTION fail_activity();');
  await asUser(owner);
  await rejectsCode(() => edit(full), 'P0001');
  assert.equal((await db.query('SELECT visibility FROM tastings WHERE id=$1',[log])).rows[0].visibility, 'everyone');
  await db.exec('RESET ROLE; DROP TRIGGER fail_activity ON activity_feed;');
});

await t.test('delete cascades only through tasting_id, preserving another log of the same wine', async () => {
  await asUser(owner);
  await db.query('DELETE FROM tastings WHERE id=$1', [log]);
  assert.equal(await count('activity_feed', 'tasting_id=$1',[log]), 0);
  assert.equal(await count('tastings', 'id=$1',['30000000-0000-0000-0000-000000000002']), 1);
});

await t.test('invalid ratings/structure cannot create partial records', async () => {
  await asUser(owner);
  for (const payload of [{...full,rating:11}, {...full,body:6}, {...full,visibility:'invalid'}]) {
    await rejectsCode(() => create(log, payload), '23514');
    assert.equal(await count('tastings','id=$1',[log]), 0);
  }
});

await t.test('private image bucket and internal taste helper are locked', async () => {
  await db.exec('RESET ROLE');
  assert.equal((await db.query("SELECT public FROM storage.buckets WHERE id='moment_images'")).rows[0].public, false);
  await asUser(owner);
  await rejectsCode(() => db.query('SELECT compute_user_taste_profile($1)',[stranger]), '42501');
});

});
