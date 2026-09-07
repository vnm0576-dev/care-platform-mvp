# Isolated synthetic-only Supabase Compose PoC

This directory implements Issue #74. It prepares an upstream Supabase self-hosted snapshot, generates untracked local secrets, applies the repository migration chain to the real Supabase-managed `auth.users`, and exercises Auth/PostgREST with synthetic users and JWTs.

## Evidence boundary

This is a disposable local PoC. It does not prove Russian staging, TLS, private S3, SMTP/SMS delivery, backup/restore, production sizing, legal compliance, or readiness for real personal/health data. Only synthetic `example.invalid` identities and invented profile text are used.

The approved upstream source is pinned in `provenance.env`; exact image tags are recorded in `images.lock`. The source archive is checksum-verified before extraction. The tag is annotated but upstream reports it as unsigned, so the pinned commit and archive SHA-256 are the integrity anchors reviewed for this PoC.

## Safety properties

- runtime files, database data, reports and `.env` stay under ignored `.runtime/`/`reports/` paths;
- secrets are generated with OS cryptographic randomness, written with mode `0600`, never emitted by project scripts;
- upstream default credentials are replaced and startup fails if runtime configuration is missing or partial;
- API gateway, database pooler and Mailpit UI bind only to `127.0.0.1`;
- Auth email is auto-confirmed for this local run and SMTP points only to the in-stack Mailpit sink;
- phone signup/SMS is disabled;
- the selected service set excludes unused Realtime, Storage, imgproxy and Edge Runtime containers;
- Compose is forced to the unique `care-platform-supabase-poc` project, and selected containers use PoC-specific names and ownership labels;
- destructive cleanup requires an explicit `--confirm-destroy` argument, validates canonical repository/sentinel markers and resource ownership, and verifies no owned resources or local artifacts remain.

The PoC override replaces the upstream fixed global `container_name` values. Startup fails rather than reuse a PoC container name carrying unexpected ownership labels.

## Requirements

The official complete-stack guidance for the reviewed snapshot lists 4 GB RAM, 2 CPU cores and 40 GB SSD as minimum, with 8 GB+ RAM, 4+ cores and 80 GB+ recommended. `poc.sh preflight` enforces the minimum RAM/free-disk checks. Running a reduced service set lowers load but does not convert this host into a production-sized environment.

Required commands: Docker Engine, Docker Compose v2 with `!override` support, Python 3, OpenSSL and curl.

## Run

From the repository root:

```bash
python3 -m unittest infra/supabase-poc/tests/test_poc_contract.py -v
infra/supabase-poc/poc.sh all
```

Or step by step:

```bash
infra/supabase-poc/poc.sh prepare
infra/supabase-poc/poc.sh preflight
infra/supabase-poc/poc.sh start
infra/supabase-poc/poc.sh migrate
infra/supabase-poc/poc.sh smoke
infra/supabase-poc/poc.sh report
```

The API is reachable only from the host at `http://127.0.0.1:18000`; Mailpit UI is host-only at `http://127.0.0.1:18025`; session and transaction pooler ports are host-only at `15432` and `16543`. Studio is routed through the same loopback API gateway and protected by the generated Basic Auth credentials, which remain in the untracked runtime `.env`.

The smoke script verifies:

1. real GoTrue signup and password login for caregiver, client and admin candidate;
2. automatic `auth.users` → `public.profiles` trigger behavior;
3. caregiver draft creation and protected submission RPC;
4. service-side admin bootstrap and protected moderation RPC;
5. caregiver/client denial of admin bootstrap and moderation RPCs, with unchanged state;
6. anonymous read denial and cross-user read/update/delete denial, with unchanged state;
7. approved client projection with `contact_phone = NULL`;
8. denial of the client projection to a caregiver;
9. denial of direct moderation-status updates.

No token, password, private API key or synthetic record identifier is printed.

## Stop and cleanup

Preserve the disposable database but stop containers:

```bash
infra/supabase-poc/poc.sh stop
```

Delete containers, named volumes, runtime secrets, synthetic records and local reports:

```bash
infra/supabase-poc/poc.sh destroy --confirm-destroy
```

The destroy command is irreversible for this disposable PoC. It does not touch the repository migrations or any external Supabase project.
