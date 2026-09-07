#!/usr/bin/env python3
import argparse
import base64
import hashlib
import hmac
import json
import os
import secrets
import sys
import time
from pathlib import Path


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def jwt_for_role(secret: str, role: str) -> str:
    now = int(time.time())
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    payload = b64url(
        json.dumps(
            {"role": role, "iss": "supabase", "iat": now, "exp": now + 5 * 365 * 86400},
            separators=(",", ":"),
        ).encode()
    )
    signed = f"{header}.{payload}"
    signature = b64url(hmac.new(secret.encode(), signed.encode(), hashlib.sha256).digest())
    return f"{signed}.{signature}"


def replace_values(source: str) -> str:
    jwt_secret = b64url(secrets.token_bytes(40))
    replacements = {
        "COMPOSE_FILE": "docker-compose.yml:compose.poc.yml",
        "POSTGRES_PASSWORD": secrets.token_hex(24),
        "JWT_SECRET": jwt_secret,
        "ANON_KEY": jwt_for_role(jwt_secret, "anon"),
        "SERVICE_ROLE_KEY": jwt_for_role(jwt_secret, "service_role"),
        "DASHBOARD_USERNAME": "care_poc",
        "DASHBOARD_PASSWORD": secrets.token_hex(24),
        "SECRET_KEY_BASE": b64url(secrets.token_bytes(48)),
        "REALTIME_DB_ENC_KEY": secrets.token_hex(8),
        "VAULT_ENC_KEY": secrets.token_hex(16),
        "PG_META_CRYPTO_KEY": b64url(secrets.token_bytes(32)),
        "LOGFLARE_PUBLIC_ACCESS_TOKEN": b64url(secrets.token_bytes(32)),
        "LOGFLARE_PRIVATE_ACCESS_TOKEN": b64url(secrets.token_bytes(32)),
        "S3_PROTOCOL_ACCESS_KEY_ID": secrets.token_hex(16),
        "S3_PROTOCOL_ACCESS_KEY_SECRET": secrets.token_hex(32),
        "MINIO_ROOT_PASSWORD": secrets.token_hex(24),
        "OPENAI_API_KEY": "",
        "SUPABASE_PUBLIC_URL": "http://127.0.0.1:18000",
        "API_EXTERNAL_URL": "http://127.0.0.1:18000/auth/v1",
        "SITE_URL": "http://127.0.0.1:18001",
        "ADDITIONAL_REDIRECT_URLS": "",
        "ENABLE_EMAIL_AUTOCONFIRM": "true",
        "ENABLE_PHONE_SIGNUP": "false",
        "ENABLE_PHONE_AUTOCONFIRM": "false",
        "SMTP_ADMIN_EMAIL": "synthetic-only@example.invalid",
        "SMTP_HOST": "mailpit",
        "SMTP_PORT": "1025",
        "SMTP_USER": "synthetic-only",
        "SMTP_PASS": "synthetic-only",
        "SMTP_SENDER_NAME": "Care Platform synthetic PoC",
        "FUNCTIONS_VERIFY_JWT": "true",
    }
    seen = set()
    output = []
    for line in source.splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key = line.split("=", 1)[0]
            if key in replacements:
                line = f"{key}={replacements[key]}"
                seen.add(key)
        output.append(line)
    missing = sorted(set(replacements) - seen)
    if missing:
        output.extend(["", "# Care Platform synthetic PoC overrides"])
        output.extend(f"{key}={replacements[key]}" for key in missing)
    output.extend(
        [
            "",
            "# Loopback host ports for the synthetic PoC",
            "POC_API_PORT=18000",
            "POC_DB_PORT=15432",
            "POC_POOLER_PORT=16543",
            "POC_MAILPIT_PORT=18025",
        ]
    )
    return "\n".join(output) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    args = parser.parse_args()
    if not args.source.is_file():
        print("ERROR: upstream .env.example is missing", file=sys.stderr)
        return 2
    if args.target.exists():
        print("ERROR: refusing to overwrite an existing secret environment", file=sys.stderr)
        return 2
    content = replace_values(args.source.read_text())
    old_umask = os.umask(0o177)
    try:
        args.target.write_text(content)
        args.target.chmod(0o600)
    finally:
        os.umask(old_umask)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
