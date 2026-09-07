#!/usr/bin/env python3
import json
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".runtime" / "project" / ".env"


def load_env() -> dict[str, str]:
    values = {}
    for line in ENV_FILE.read_text().splitlines():
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    required = ("ANON_KEY", "SERVICE_ROLE_KEY", "SUPABASE_PUBLIC_URL")
    if any(not values.get(key) for key in required):
        raise RuntimeError("required runtime configuration is missing")
    return values


def request(base, path, key, token=None, method="GET", body=None, prefer=None):
    headers = {"apikey": key, "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            payload = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            payload = None
        return error.code, payload


def require(condition, message):
    if not condition:
        raise AssertionError(message)
    print(f"PASS: {message}")


def signup(base, anon_key, email, password, role):
    status, payload = request(
        base,
        "/auth/v1/signup",
        anon_key,
        method="POST",
        body={
            "email": email,
            "password": password,
            "data": {"full_name": f"Synthetic {role}", "role": role},
        },
    )
    require(status == 200 and payload.get("user", {}).get("id"), f"real Auth signup creates {role}")
    return payload["user"]["id"]


def login(base, anon_key, email, password):
    status, payload = request(
        base,
        "/auth/v1/token?grant_type=password",
        anon_key,
        method="POST",
        body={"email": email, "password": password},
    )
    require(status == 200 and payload.get("access_token"), "real Auth password login returns a JWT")
    return payload["access_token"]


def main() -> int:
    env = load_env()
    base = env["SUPABASE_PUBLIC_URL"].rstrip("/")
    anon = env["ANON_KEY"]
    service_role = env["SERVICE_ROLE_KEY"]
    run_id = secrets.token_hex(5)
    password = secrets.token_urlsafe(18)
    accounts = {
        role: f"synthetic-{role}-{run_id}@example.invalid"
        for role in ("caregiver", "other-caregiver", "client", "admin-candidate")
    }

    caregiver_id = signup(base, anon, accounts["caregiver"], password, "caregiver")
    other_id = signup(base, anon, accounts["other-caregiver"], password, "caregiver")
    client_id = signup(base, anon, accounts["client"], password, "client")
    admin_id = signup(base, anon, accounts["admin-candidate"], password, "client")
    ids = (caregiver_id, other_id, client_id, admin_id)
    require(len(set(ids)) == 4, "synthetic Auth identities are distinct")

    caregiver_token = login(base, anon, accounts["caregiver"], password)
    other_token = login(base, anon, accounts["other-caregiver"], password)
    client_token = login(base, anon, accounts["client"], password)
    admin_token = login(base, anon, accounts["admin-candidate"], password)

    profile = {
        "profile_id": caregiver_id,
        "full_name": "Synthetic Caregiver",
        "city": "Synthetic City",
        "contact_phone": "+70000000000",
        "experience": "Synthetic experience only",
        "skills": ["Synthetic assistance"],
        "schedule": "Synthetic schedule",
        "description": "Synthetic profile without real personal or health data",
    }
    status, rows = request(
        base,
        "/rest/v1/caregiver_profiles?select=id,status",
        anon,
        caregiver_token,
        method="POST",
        body=profile,
        prefer="return=representation",
    )
    require(status == 201 and len(rows) == 1 and rows[0]["status"] == "draft", "caregiver creates own draft over REST")
    questionnaire_id = rows[0]["id"]

    encoded = urllib.parse.quote(questionnaire_id, safe="")
    status, rows = request(base, f"/rest/v1/caregiver_profiles?id=eq.{encoded}", anon, other_token)
    require(status == 200 and rows == [], "cross-caregiver raw read is denied by RLS")
    status, rows = request(base, f"/rest/v1/caregiver_profiles?id=eq.{encoded}", anon, client_token)
    require(status == 200 and rows == [], "client raw caregiver read is denied by RLS")
    status, rows = request(base, f"/rest/v1/caregiver_profiles?id=eq.{encoded}", anon)
    require(
        status in (200, 401, 403) and (status != 200 or rows == []),
        "anonymous raw caregiver access is denied",
    )

    status, rows = request(
        base,
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}&select=id,city,status",
        anon,
        other_token,
        method="PATCH",
        body={"city": "Unauthorized synthetic city"},
        prefer="return=representation",
    )
    require(
        status in (200, 401, 403) and (status != 200 or rows == []),
        "cross-user update is denied",
    )
    status, rows = request(
        base,
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}&select=id,city,status",
        anon,
        caregiver_token,
    )
    require(
        status == 200
        and isinstance(rows, list)
        and len(rows) == 1
        and rows[0]["city"] == "Synthetic City"
        and rows[0]["status"] == "draft",
        "cross-user update leaves caregiver profile unchanged",
    )

    status, rows = request(
        base,
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}",
        anon,
        other_token,
        method="DELETE",
        prefer="return=representation",
    )
    require(
        status in (200, 401, 403) and (status != 200 or rows == []),
        "cross-user delete is denied",
    )
    status, rows = request(
        base,
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}&select=id,city,status",
        anon,
        caregiver_token,
    )
    require(
        status == 200
        and isinstance(rows, list)
        and len(rows) == 1
        and rows[0]["status"] == "draft",
        "cross-user delete leaves caregiver profile unchanged",
    )

    status, _ = request(
        base,
        "/rest/v1/rpc/submit_caregiver_profile",
        anon,
        caregiver_token,
        method="POST",
        body={"p_caregiver_profile_id": questionnaire_id},
    )
    require(status in (200, 204), "caregiver submits questionnaire through protected RPC")

    for actor, token in (("caregiver", caregiver_token), ("client", client_token)):
        status, _ = request(
            base,
            "/rest/v1/rpc/bootstrap_admin",
            anon,
            token,
            method="POST",
            body={"p_profile_id": admin_id},
        )
        require(
            status in (401, 403, 404),
            f"ordinary {actor} cannot bootstrap an administrator",
        )

    admin_encoded = urllib.parse.quote(admin_id, safe="")
    status, rows = request(
        base,
        f"/rest/v1/profiles?id=eq.{admin_encoded}&select=role",
        service_role,
        service_role,
    )
    require(
        status == 200
        and isinstance(rows, list)
        and len(rows) == 1
        and rows[0]["role"] == "client",
        "denied bootstrap attempts leave the admin candidate unchanged",
    )

    moderation_body = {
        "p_caregiver_profile_id": questionnaire_id,
        "p_new_status": "approved",
        "p_reason": "Synthetic moderation acceptance",
        "p_comment": "Issue 74 HTTP smoke",
    }
    for actor, token in (("caregiver", caregiver_token), ("client", client_token)):
        status, _ = request(
            base,
            "/rest/v1/rpc/moderate_caregiver_profile",
            anon,
            token,
            method="POST",
            body=moderation_body,
        )
        require(
            status in (401, 403),
            f"ordinary {actor} cannot moderate a profile",
        )

    status, rows = request(
        base,
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}&select=status",
        anon,
        caregiver_token,
    )
    require(
        status == 200
        and isinstance(rows, list)
        and len(rows) == 1
        and rows[0]["status"] == "pending_review",
        "denied moderation attempts leave questionnaire status unchanged",
    )

    status, _ = request(
        base,
        "/rest/v1/rpc/bootstrap_admin",
        service_role,
        service_role,
        method="POST",
        body={"p_profile_id": admin_id},
    )
    require(status in (200, 204), "service-side bootstrap promotes a dedicated admin account")

    status, _ = request(
        base,
        "/rest/v1/rpc/moderate_caregiver_profile",
        anon,
        admin_token,
        method="POST",
        body=moderation_body,
    )
    require(status in (200, 204), "admin moderates through protected RPC")

    query = urllib.parse.urlencode({"city": "eq.Synthetic City", "select": "id,contact_phone"})
    status, rows = request(base, f"/rest/v1/approved_caregiver_profiles?{query}", anon, client_token)
    require(status == 200 and len(rows) == 1, "client sees the approved synthetic projection")
    require(rows[0]["contact_phone"] is None, "client projection redacts caregiver phone to NULL")

    status, rows = request(base, f"/rest/v1/approved_caregiver_profiles?{query}", anon, other_token)
    require(status == 200 and rows == [], "caregiver cannot read the client projection")

    status, _ = request(
        base,
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}",
        anon,
        caregiver_token,
        method="PATCH",
        body={"status": "approved"},
        prefer="return=representation",
    )
    require(status in (400, 401, 403), "ordinary user cannot mutate moderation status directly")
    print("Synthetic HTTP/JWT smoke completed; no secrets were printed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"FAIL: {type(error).__name__}: {error}", file=sys.stderr)
        raise SystemExit(1)
