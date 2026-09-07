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
        for role in (
            "caregiver",
            "other-caregiver",
            "client",
            "other-client",
            "admin-candidate",
        )
    }

    caregiver_id = signup(base, anon, accounts["caregiver"], password, "caregiver")
    other_id = signup(base, anon, accounts["other-caregiver"], password, "caregiver")
    client_id = signup(base, anon, accounts["client"], password, "client")
    other_client_id = signup(base, anon, accounts["other-client"], password, "client")
    admin_id = signup(base, anon, accounts["admin-candidate"], password, "client")
    ids = (caregiver_id, other_id, client_id, other_client_id, admin_id)
    require(len(set(ids)) == 5, "synthetic Auth identities are distinct")

    caregiver_token = login(base, anon, accounts["caregiver"], password)
    other_token = login(base, anon, accounts["other-caregiver"], password)
    client_token = login(base, anon, accounts["client"], password)
    other_client_token = login(base, anon, accounts["other-client"], password)
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
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}",
        anon,
        caregiver_token,
        method="PATCH",
        body={"status": "approved"},
        prefer="return=representation",
    )
    require(
        status in (400, 401, 403),
        "owner cannot mutate draft moderation status directly",
    )
    status, rows = request(
        base,
        f"/rest/v1/caregiver_profiles?id=eq.{encoded}&select=id,status",
        anon,
        caregiver_token,
    )
    require(
        status == 200
        and isinstance(rows, list)
        and len(rows) == 1
        and rows[0]["status"] == "draft",
        "denied direct status write leaves questionnaire in draft",
    )

    client_request = {
        "profile_id": client_id,
        "city": "Synthetic Request City",
        "district": "Synthetic District",
        "care_type": "Synthetic household assistance",
        "description": "Invented non-clinical request for authorization testing",
        "contact_phone": "+700****1000",
        "preferred_schedule": "Synthetic daytime schedule",
        "desired_payment": 0,
        "needs_live_in": False,
        "needs_night_shifts": False,
        "dementia_case": False,
        "bedridden_case": False,
        "stroke_case": False,
        "heart_attack_case": False,
        "trauma_case": False,
    }
    client_requests_path = "/rest/v1/client_requests"
    negative_actors = (
        ("anonymous", None),
        ("caregiver", caregiver_token),
        ("other-client", other_client_token),
    )
    for actor, token in negative_actors:
        status, _ = request(
            base,
            f"{client_requests_path}?select=id,profile_id,city",
            anon,
            token,
            method="POST",
            body=client_request,
            prefer="return=representation",
        )
        require(
            status in (401, 403),
            f"{actor} cannot create client request for another identity",
        )
    client_id_encoded = urllib.parse.quote(client_id, safe="")
    status, rows = request(
        base,
        f"{client_requests_path}?profile_id=eq.{client_id_encoded}&select=id",
        anon,
        client_token,
    )
    require(
        status == 200 and rows == [],
        "denied cross-user creates leave client requests empty",
    )

    status, rows = request(
        base,
        f"{client_requests_path}?select=id,profile_id,city,care_type",
        anon,
        client_token,
        method="POST",
        body=client_request,
        prefer="return=representation",
    )
    require(
        status == 201
        and isinstance(rows, list)
        and len(rows) == 1
        and rows[0]["profile_id"] == client_id,
        "client creates own synthetic request over REST",
    )
    client_request_id = rows[0]["id"]
    request_id_encoded = urllib.parse.quote(client_request_id, safe="")
    owner_request_path = (
        f"{client_requests_path}?id=eq.{request_id_encoded}"
        "&select=id,profile_id,city,care_type"
    )
    status, rows = request(base, owner_request_path, anon, client_token)
    require(
        status == 200
        and isinstance(rows, list)
        and len(rows) == 1
        and rows[0]["city"] == "Synthetic Request City",
        "client reads own synthetic request over REST",
    )

    for actor, token in negative_actors:
        status, rows = request(base, owner_request_path, anon, token)
        require(
            status in (200, 401, 403) and (status != 200 or rows == []),
            f"{actor} cannot read client request owned by another identity",
        )

    for actor, token in negative_actors:
        status, rows = request(
            base,
            owner_request_path,
            anon,
            token,
            method="PATCH",
            body={"city": "Unauthorized Synthetic City"},
            prefer="return=representation",
        )
        require(
            status in (200, 401, 403) and (status != 200 or rows == []),
            f"{actor} cannot update client request owned by another identity",
        )
    status, rows = request(base, owner_request_path, anon, client_token)
    require(
        status == 200
        and len(rows) == 1
        and rows[0]["city"] == "Synthetic Request City",
        "denied client request updates leave owner state unchanged",
    )

    for actor, token in negative_actors:
        status, rows = request(
            base,
            owner_request_path,
            anon,
            token,
            method="DELETE",
            prefer="return=representation",
        )
        require(
            status in (200, 401, 403) and (status != 200 or rows == []),
            f"{actor} cannot delete client request owned by another identity",
        )
    status, rows = request(base, owner_request_path, anon, client_token)
    require(
        status == 200 and len(rows) == 1,
        "denied client request deletes leave owner state unchanged",
    )

    status, rows = request(
        base,
        owner_request_path,
        anon,
        client_token,
        method="PATCH",
        body={"city": "Synthetic Updated Request City"},
        prefer="return=representation",
    )
    require(
        status == 200
        and len(rows) == 1
        and rows[0]["city"] == "Synthetic Updated Request City",
        "client updates own synthetic request over REST",
    )
    status, rows = request(base, owner_request_path, anon, client_token)
    require(
        status == 200
        and len(rows) == 1
        and rows[0]["city"] == "Synthetic Updated Request City",
        "owner read confirms synthetic client request update",
    )

    status, rows = request(
        base,
        owner_request_path,
        anon,
        client_token,
        method="DELETE",
        prefer="return=representation",
    )
    require(
        status == 200 and len(rows) == 1,
        "client deletes own synthetic request over REST",
    )
    status, rows = request(base, owner_request_path, anon, client_token)
    require(
        status == 200 and rows == [],
        "owner read confirms synthetic client request deletion",
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

    for message, token in (
        ("client raw caregiver read remains denied after approval", client_token),
        (
            "cross-caregiver raw read remains denied after approval",
            other_token,
        ),
    ):
        status, rows = request(
            base,
            f"/rest/v1/caregiver_profiles?id=eq.{encoded}",
            anon,
            token,
        )
        require(status == 200 and rows == [], message)

    query = urllib.parse.urlencode(
        {
            "city": "eq.Synthetic City",
            "id": f"eq.{encoded}",
            "select": "id,contact_phone",
        }
    )
    status, rows = request(base, f"/rest/v1/approved_caregiver_profiles?{query}", anon, client_token)
    require(status == 200 and len(rows) == 1, "client sees the approved synthetic projection")
    require(rows[0]["contact_phone"] is None, "client projection redacts caregiver phone to NULL")

    status, rows = request(base, f"/rest/v1/approved_caregiver_profiles?{query}", anon, other_token)
    require(status == 200 and rows == [], "caregiver cannot read the client projection")

    print("Synthetic HTTP/JWT smoke completed; no secrets were printed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"FAIL: {type(error).__name__}: {error}", file=sys.stderr)
        raise SystemExit(1)
