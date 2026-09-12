import { PGlite } from '@electric-sql/pglite';
import { readFileSync, writeFileSync } from 'node:fs';
const root = '/Users/ahmet/Pari/supabase/migrations/';
const db = new PGlite();
const findings=[];
await db.exec(`
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT current_setting('request.jwt.claim.sub', true)::uuid $$;
GRANT USAGE ON SCHEMA auth, public TO authenticated;
CREATE TABLE public.wines(id uuid PRIMARY KEY);
INSERT INTO public.wines VALUES ('10000000-0000-0000-0000-000000000001');
`);
const cellar = readFileSync(root+'20260803000013_cellar_bottles.sql','utf8');
await db.exec(cellar.slice(cellar.indexOf('CREATE TABLE'),cellar.indexOf('-- ───',cellar.indexOf('CREATE TABLE'))));
try {
  await db.exec(`INSERT INTO cellar_bottles(user_id,wine_id,vintage,quantity)
    VALUES('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',2020,1)
    ON CONFLICT (user_id,wine_id,vintage) DO UPDATE SET quantity=excluded.quantity;`);
  findings.push({test:'cellar_upsert_conflict_target',reproduced:false});
} catch(e) { findings.push({test:'cellar_upsert_conflict_target',reproduced:e.code==='42P10',code:e.code,message:e.message}); }
const sessions=readFileSync(root+'20260803000011_tasting_sessions.sql','utf8');
await db.exec(sessions.slice(sessions.indexOf('CREATE TABLE'),sessions.indexOf('-- ───',sessions.indexOf('CREATE TABLE'))));
await db.exec(`INSERT INTO tasting_sessions(id,code,host_id) VALUES('20000000-0000-0000-0000-000000000001','AAAAA','00000000-0000-0000-0000-000000000001');
INSERT INTO tasting_session_members(session_id,user_id) VALUES('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
GRANT SELECT,DELETE ON tasting_sessions,tasting_session_members TO authenticated;
SET request.jwt.claim.sub='00000000-0000-0000-0000-000000000001'; SET ROLE authenticated;`);
for (const [test,sql] of [
 ['session_members_select_policy', 'SELECT * FROM tasting_session_members;'],
 ['session_leave_delete_policy', "DELETE FROM tasting_session_members WHERE session_id='20000000-0000-0000-0000-000000000001' AND user_id='00000000-0000-0000-0000-000000000001';"]
]) {
 try {await db.query(sql);findings.push({test,reproduced:false});}
 catch(e){findings.push({test,reproduced:e.code==='42P17',code:e.code,message:e.message});}
}
await db.exec(`RESET ROLE;
CREATE TABLE public.profiles(id uuid PRIMARY KEY,activity_visibility text,deleted_at timestamptz);
CREATE TABLE public.tastings(id uuid PRIMARY KEY,user_id uuid,visibility text);
INSERT INTO profiles VALUES('00000000-0000-0000-0000-000000000001','everyone',NULL);
INSERT INTO tastings VALUES('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','friends');
CREATE FUNCTION public.is_mutual_friend(uuid,uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
ALTER TABLE tastings ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON profiles,tastings TO authenticated;`);
const privacy=readFileSync(root+'20250801000000_privacy_rls_feed_audit.sql','utf8');
const helper=privacy.match(/CREATE OR REPLACE FUNCTION public\.can_view_activity[\s\S]*?\$\$;/)[0];
const policy=privacy.match(/CREATE POLICY "tastings_select_privacy"[\s\S]*?\n  \);/)[0];
await db.exec(helper+policy);
await db.exec(`SET request.jwt.claim.sub='00000000-0000-0000-0000-000000000002'; SET ROLE authenticated;`);
const visible=await db.query('SELECT visibility FROM tastings');
findings.push({test:'friends_only_tasting_visible_to_nonfriend',reproduced:visible.rows.length===1,visible_rows:visible.rows});
await db.exec('RESET ROLE');
await db.close();
const result={environment:'PGlite 0.5.8, isolated in-memory PostgreSQL; original schema/policy fragments; synthetic users only',findings};
writeFileSync('/tmp/pari-audit-20260911/sql-reproductions.json',JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));
if(!findings.every(x=>x.reproduced))process.exitCode=1;
