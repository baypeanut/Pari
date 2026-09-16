import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

await test('session membership permits reading and leaving without RLS recursion', async t => {
  const db = new PGlite();
  t.after(() => db.close());
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    GRANT USAGE ON SCHEMA auth,public TO authenticated;`);
  const migration = name => readFileSync(new URL(`../migrations/${name}.sql`, import.meta.url), 'utf8');
  const sessions = migration('20260803000011_tasting_sessions');
  // Membership does not require pgvector or the recommendation function.
  await db.exec(sessions.slice(0, sessions.indexOf('DROP FUNCTION IF EXISTS public.recommend_wines_group')) + 'COMMIT;');
  await db.exec('GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;');
  await db.exec(migration('20260916000000_session_membership'));
  const owner = '00000000-0000-0000-0000-000000000001';
  const guest = '00000000-0000-0000-0000-000000000002';
  const outsider = '00000000-0000-0000-0000-000000000003';
  await db.exec(`INSERT INTO auth.users VALUES ('${owner}'),('${guest}'),('${outsider}');`);
  const asUser = async id => {
    await db.exec('RESET ROLE');
    await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [id]);
    await db.exec('SET ROLE authenticated');
  };
  const members = async () => (await db.query('SELECT * FROM tasting_session_members')).rows.length;
  await asUser(owner);
  const session = (await db.query('SELECT * FROM create_tasting_session($1)', ['Regression'])).rows[0];
  assert.equal(await members(), 1);
  await asUser(outsider);
  assert.equal(await members(), 0);
  assert.equal((await db.query('SELECT * FROM tasting_sessions')).rows.length, 0);
  await asUser(guest);
  await db.query('SELECT * FROM join_tasting_session($1)', [session.code.toLowerCase()]);
  assert.equal(await members(), 2);
  await db.query('SELECT leave_tasting_session($1)', [session.session_id]);
  assert.equal(await members(), 0);
  // A lost leave response can be retried without removing another member.
  await db.query('SELECT leave_tasting_session($1)', [session.session_id]);
  await asUser(owner);
  assert.equal(await members(), 1);
  // Older clients use a conditional DELETE; that path must also work.
  await db.query('DELETE FROM tasting_session_members WHERE session_id=$1 AND user_id=$2', [session.session_id, owner]);
  assert.equal(await members(), 0);
});
