#!/usr/bin/env python3
"""Read-only schema preflight for the backend used by the iOS app.

Requires SUPABASE_ACCESS_TOKEN (a Management API token). The project ref is read
from the local, ignored SupabaseConfig.swift, or SUPABASE_PROJECT_REF in CI.
No tokens or user rows are printed. A missing contract exits nonzero.
"""
import json
import os
from pathlib import Path
import re
import ssl
import sys
import urllib.error
import urllib.request

REQUIRED = {
    "tastings": "id user_id wine_id rating note_tags comment created_at source visibility vintage acidity tannin body sweetness aroma_intensity finish moment_image_url",
    "profiles": "id username deleted_at activity_visibility cellar_visibility wishlist_visibility phone_hash",
    "cellar_bottles": "id user_id wine_id vintage quantity location",
    "tasting_sessions": "id code host_id expires_at",
    "tasting_session_members": "session_id user_id",
    "curated_collections": "id title",
    "curated_collection_wines": "collection_id wine_id",
    "label_scan_usage": "user_id",
    "blocks": "blocker_id blocked_id",
    "reports": "reporter_id content_type content_id reason",
}
RPCS = "create_tasting update_tasting add_cellar_bottles drink_cellar_bottle feed_global feed_following search_wines get_my_taste_profile get_taste_twins recommend_wines get_curated_collections get_collection_wines open_tonight create_tasting_session join_tasting_session leave_tasting_session recommend_wines_group match_wine_list consume_label_scan_quota".split()


def main():
    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token:
        sys.exit("SUPABASE_ACCESS_TOKEN is required for the read-only contract check.")
    ref = os.environ.get("SUPABASE_PROJECT_REF")
    if not ref:
        config = Path(__file__).resolve().parents[1] / "Pari/Core/SupabaseConfig.swift"
        ref = re.search(r"https://([a-z0-9-]+)\.supabase\.co", config.read_text()).group(1)
    query = """select jsonb_build_object(
      'columns',(select jsonb_agg(jsonb_build_object('table',table_name,'column',column_name))
        from information_schema.columns where table_schema='public'),
      'functions',(select jsonb_agg(jsonb_build_object('name',p.proname,'args',pg_get_function_identity_arguments(p.oid))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'),
      'private_moments',(select not public from storage.buckets where id='moment_images')
    ) as contract"""
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{ref}/database/query/read-only",
        data=json.dumps({"query": query}).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    cert = '/etc/ssl/cert.pem'
    context = ssl.create_default_context(cafile=cert if Path(cert).exists() else None)
    try:
        with urllib.request.urlopen(req, context=context, timeout=30) as response:
            actual = json.load(response)[0]['contract']
    except urllib.error.HTTPError as error:
        sys.exit(f"Backend preflight failed: HTTP {error.code}")
    columns = {(c['table'], c['column']) for c in actual['columns']}
    missing = [f'{table}.{column}' for table, fields in REQUIRED.items()
               for column in fields.split() if (table, column) not in columns]
    names = {f['name'] for f in actual['functions']}
    missing += [f'RPC {rpc}' for rpc in RPCS if rpc not in names]
    for name in ['feed_global', 'feed_following']:
        if not any(f['name'] == name and 'p_cursor timestamp with time zone' in f['args'] for f in actual['functions']):
            missing.append(f'cursor signature for {name}')
    if not actual['private_moments']:
        missing.append('private moment_images bucket')
    if missing:
        sys.exit('Backend contract is incomplete:\n' + '\n'.join(missing))
    print(f'Backend schema contract passed: {len(REQUIRED)} tables, {len(RPCS)} RPCs, private moments.')


if __name__ == '__main__':
    main()
