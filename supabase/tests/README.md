# Database regression tests

Run from the repository root with Node.js:

```sh
npm --prefix supabase/tests ci --ignore-scripts
npm --prefix supabase/tests test
```

The suite uses pinned PGlite 0.5.8 (embedded PostgreSQL). It never connects to a
Supabase project. All three `20260911` migrations run verbatim against synthetic
users and wines. Earlier table definitions, RLS policies and the latest feed
view/RPC definitions are loaded from the repository's migration files.

The 16 tasting scenarios cover save replay, full-field edits and clearing, atomic rollback,
ownership, validation, linked deletion, legacy links, public/friends/profile
privacy, anonymous access, friendship revocation, both feed RPCs, the feed view,
interaction access, Storage object policies and the taste helper's execute grant.
The 13 cellar scenarios cover additive stock changes, unknown and known vintages,
replay receipts, mismatched requests, ownership, empty stock, input validation,
direct-write restrictions, rollback in both directions and integer overflow.

The September 11, 12 and 16 migrations run verbatim across the relevant fixture
databases. The session test covers host/join/read/leave, repeat leave and access
by an outsider. Four moderation scenarios cover mutual blocks, private report
submission, uppercase UUID avatar ownership and removal of anonymous profile writes.
Node reports **37 passing tests**, including parent tests.

This is **not a full Supabase stack test**: Auth and Storage infrastructure are
fixtures; the pgvector helper is a permission-test stub; embedding triggers,
PostgREST serialization, real object downloads, CDN behavior and parallel network
requests require staging verification. Replay tests use sequential requests.
PostgreSQL's primary-key conflict handling serializes concurrent saves of the
same ID, but that needs an API-level concurrency check before release.

For the September 16 real PostgreSQL, live HTTP, Storage and iOS verification,
see [the backend repair report](../../docs/engineering/backend-repair-2026-09-16.md).
