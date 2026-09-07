# Synthetic Supabase PoC run — Issue #74

## Evidence boundary

This report records a disposable local run on the existing Hermes VPS after Vladimir explicitly approved Docker installation and execution on that host. It is not evidence of Russian staging, production readiness, TLS, private S3, external SMTP/SMS, backup/restore qualification or permission to process real personal/health data.

## Environment

- final run time: `2026-09-07T10:48:57+00:00`;
- upstream source: `self-hosted/v0.8.0`, commit `241bb11c0627f2981746d37033f57dbfa81d29b0`;
- archive SHA-256: `77b4341e7b50df9c4da1cfbd012c04f90e1eef5695e09a727427dbd6ac9c569f`;
- Docker Engine: `29.1.3`;
- Docker Compose: `2.40.3+ds1-0ubuntu1~24.04.1`;
- host memory: `4009504 KiB`;
- free disk at the final report: `59277444 KiB`;
- active reduced stack: Mailpit, PostgreSQL, GoTrue, PostgREST, postgres-meta, Studio, Envoy and Supavisor.

## Final result

The final clean run completed with exit code `0`:

1. verified and extracted the pinned upstream archive;
2. generated private untracked secrets with mode `0600`;
3. resolved and pulled eight active images pinned by tag and repository digest;
4. started all selected containers healthy;
5. verified API, both pooler ports and Mailpit UI were bound only to `127.0.0.1`;
6. applied all 11 repository migrations in timestamp order to the real Supabase PostgreSQL/Auth schema;
7. completed real HTTP/JWT signup and password login;
8. created/submitted a caregiver questionnaire, promoted a dedicated admin and moderated the questionnaire through protected RPCs;
9. confirmed anonymous and cross-user raw-row denial, cross-user update/delete denial with unchanged state, ordinary-role denial for bootstrap/moderation RPCs, client-only approved projection, `contact_phone = NULL`, caregiver projection denial and direct status-update denial.

No secret, token, password or synthetic record identifier was printed by project scripts.

## Resource snapshot

All eight selected containers were healthy. Their one-shot reported memory usage summed to approximately `796.66 MiB`. This is an observation from one synthetic smoke run, not a capacity estimate. CPU values were transient (`0.00%`–`1.90%`).

## Failed attempts retained honestly

Implementation and review defects found before the final clean run:

1. `poc.sh` initially calculated its root as `infra/` instead of `infra/supabase-poc/`;
2. Docker Compose initially resolved `COMPOSE_FILE` relative to the invocation directory; the wrapper now passes both Compose files by absolute path;
3. first cleanup could not remove PostgreSQL's root-owned bind-mounted data; destructive cleanup now handles an absent/partial runtime and uses non-interactive sudo only for the known disposable runtime/report paths when normal removal fails.
4. independent pre-commit review rejected globally scoped Compose cleanup, insufficient sentinel/path validation and incomplete negative role tests; cleanup is now project- and label-scoped with canonical path validation, and the HTTP/JWT smoke includes the missing negative assertions;
5. the first expanded smoke expected anonymous raw-table access to return an empty `200` response, while the live gateway correctly denied it with an authorization response; the assertion now accepts either an authorization denial or an empty RLS result and still rejects exposed rows.

After each correction, the PoC was destroyed and rebuilt from a clean runtime. The final run above is the post-fix result.

## Remaining gates

- move the stack to an approved isolated Russian staging environment;
- add domain, DNS, TLS, redirect allowlist and perimeter tests;
- select and test private Russian S3 separately;
- qualify Russian SMTP only when required; SMS remains disabled;
- perform backup/restore and measure RPO/RTO in a separate destructive exercise;
- complete legal/IB gates before any real user or health-related data;
- confirm production sizing under representative load.
