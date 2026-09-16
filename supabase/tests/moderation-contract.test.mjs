import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

await test('moderation and avatar contracts', async t => {
  const db = new PGlite(); t.after(() => db.close());
  const owner='aaaaaaaa-0000-0000-0000-000000000001', other='bbbbbbbb-0000-0000-0000-000000000002';
  await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    CREATE TABLE profiles(id uuid PRIMARY KEY, username text);
    CREATE TABLE tastings(user_id uuid); CREATE TABLE activity_feed(user_id uuid);
    ALTER TABLE profiles ENABLE ROW LEVEL SECURITY; ALTER TABLE tastings ENABLE ROW LEVEL SECURITY; ALTER TABLE activity_feed ENABLE ROW LEVEL SECURITY;
    CREATE POLICY profile_read ON profiles FOR SELECT USING(true);
    CREATE POLICY tasting_read ON tastings FOR SELECT USING(true);
    CREATE POLICY activity_read ON activity_feed FOR SELECT USING(true);
    CREATE POLICY dev_mock_profiles_update ON profiles FOR UPDATE USING(auth.uid() IS NULL);
    CREATE SCHEMA storage; CREATE TABLE storage.objects(bucket_id text,name text);
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
    CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql AS $$ SELECT string_to_array($1,'/') $$;
    CREATE POLICY avatar_read ON storage.objects FOR SELECT USING(bucket_id='avatars');
    CREATE POLICY avatars_insert ON storage.objects FOR INSERT WITH CHECK(bucket_id='avatars');
    CREATE POLICY avatars_update ON storage.objects FOR UPDATE USING(bucket_id='avatars');
    CREATE POLICY avatars_delete ON storage.objects FOR DELETE USING(bucket_id='avatars');
    GRANT USAGE ON SCHEMA public,auth,storage TO anon,authenticated;
    GRANT ALL ON ALL TABLES IN SCHEMA public,storage TO anon,authenticated;
    INSERT INTO auth.users VALUES ('${owner}'),('${other}');
    INSERT INTO profiles VALUES ('${owner}','owner'),('${other}','other');
    INSERT INTO tastings VALUES ('${other}'); INSERT INTO activity_feed VALUES ('${other}');`);
  await db.exec(readFileSync(new URL('../migrations/20260916000001_moderation_contract.sql',import.meta.url),'utf8'));
  const asUser=async (id,role='authenticated')=>{await db.exec('RESET ROLE');await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec(`SET ROLE ${role}`);};
  await t.test('a block hides both profiles and activity, then unblock restores them',async()=>{
    await asUser(owner);
    await db.query('INSERT INTO blocks(blocker_id,blocked_id) VALUES($1,$2)',[owner,other]);
    for (const table of ['tastings','activity_feed']) assert.equal((await db.query(`SELECT * FROM ${table}`)).rows.length,0);
    assert.equal((await db.query('SELECT * FROM profiles')).rows.length,1);
    await asUser(other); assert.equal((await db.query('SELECT * FROM profiles')).rows.length,1);
    assert.equal((await db.query('SELECT * FROM blocks')).rows.length,0);
    await asUser(owner); await db.exec('DELETE FROM blocks');
    assert.equal((await db.query('SELECT * FROM profiles')).rows.length,2);
  });
  await t.test('a report can be submitted but its queue cannot be read',async()=>{
    await asUser(owner);
    await db.query("INSERT INTO reports(reporter_id,reported_user_id,content_type,content_id,reason) VALUES($1,$2,'user',$2,'spam')",[owner,other]);
    await assert.rejects(()=>db.query('SELECT * FROM reports'),e=>e.code==='42501');
  });
  await t.test('Swift uppercase UUID avatar paths work while another user cannot overwrite',async()=>{
    await asUser(owner); const path=owner.toUpperCase()+'/avatar.jpg';
    await db.query("INSERT INTO storage.objects VALUES('avatars',$1)",[path]);
    await asUser(other);
    assert.equal((await db.query("UPDATE storage.objects SET name='hijacked' WHERE name=$1 RETURNING *",[path])).rows.length,0);
    await assert.rejects(()=>db.query("INSERT INTO storage.objects VALUES('avatars',$1)",[path]),e=>e.code==='42501');
  });
  await t.test('anonymous sessions cannot use the old dev profile write policy',async()=>{
    await asUser('','anon');
    assert.equal((await db.query("UPDATE profiles SET username='hijacked' RETURNING *")).rows.length,0);
  });
});
