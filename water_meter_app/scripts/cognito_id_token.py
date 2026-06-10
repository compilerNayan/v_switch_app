#!/usr/bin/env python3
"""Fetch a Cognito ID token using email + password."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import urllib.error
import urllib.request


def _require(value: str, name: str) -> str:
    if not value or not value.strip():
        raise RuntimeError(f"{name} is required")
    return value.strip()


def _cognito_url(region: str) -> str:
    region = _require(region, "region")
    return f"https://cognito-idp.{region}.amazonaws.com/"


def _curl_cognito_request(region: str, target: str, payload: dict) -> dict:
    curl = shutil.which("curl")
    if curl is None:
        raise RuntimeError("curl not found on PATH")

    url = _cognito_url(region)
    body = json.dumps(payload)
    result = subprocess.run(
        [
            curl,
            "-sS",
            "--max-time",
            "30",
            "-X",
            "POST",
            url,
            "-H",
            "Content-Type: application/x-amz-json-1.1",
            "-H",
            f"X-Amz-Target: {target}",
            "-d",
            body,
            "-w",
            "\n__HTTP_CODE__:%{http_code}",
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"curl failed to reach Cognito ({url}): {result.stderr.strip() or result.stdout.strip()}"
        )

    raw = result.stdout
    if "\n__HTTP_CODE__:" in raw:
        response_body, _, code_part = raw.rpartition("\n__HTTP_CODE__:")
        http_code = code_part.strip()
    else:
        response_body, http_code = raw, "000"

    try:
        parsed = json.loads(response_body) if response_body.strip() else {}
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"Cognito returned non-JSON (HTTP {http_code}): {response_body[:500]}"
        ) from exc

    if http_code.startswith("4") or http_code.startswith("5"):
        message = parsed.get("message", response_body)
        raise RuntimeError(f"Cognito sign-in failed (HTTP {http_code}): {message}")

    return parsed


def _urllib_cognito_request(region: str, target: str, payload: dict) -> dict:
    url = _cognito_url(region)
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=body, method="POST")
    request.add_header("Content-Type", "application/x-amz-json-1.1")
    request.add_header("X-Amz-Target", target)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def _cognito_request(region: str, target: str, payload: dict) -> dict:
    try:
        return _curl_cognito_request(region, target, payload)
    except RuntimeError:
        raise
    except Exception as curl_error:
        try:
            return _urllib_cognito_request(region, target, payload)
        except urllib.error.URLError as urllib_error:
            raise RuntimeError(
                f"Could not reach Cognito at {_cognito_url(region)}. "
                "Check internet/DNS, then retry. "
                f"curl error: {curl_error}; urllib error: {urllib_error}"
            ) from urllib_error
        except Exception as urllib_error:
            raise RuntimeError(
                f"Cognito request failed via curl ({curl_error}) and urllib ({urllib_error})"
            ) from urllib_error


def _password_auth(
    region: str, client_id: str, username: str, password: str
) -> dict:
    return _cognito_request(
        region,
        "AWSCognitoIdentityProviderService.InitiateAuth",
        {
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": client_id,
            "AuthParameters": {
                "USERNAME": username,
                "PASSWORD": password,
            },
        },
    )


def _srp_auth(
    user_pool_id: str, client_id: str, username: str, password: str
) -> str:
    try:
        from pycognito import Cognito
    except ImportError as exc:
        raise RuntimeError(
            "pycognito is required for SRP sign-in. Install with: "
            "python3 -m pip install --user pycognito"
        ) from exc

    user = Cognito(user_pool_id, client_id, username=username)
    user.authenticate(password=password)
    if not user.id_token:
        raise RuntimeError("SRP authentication succeeded but no ID token was returned")
    return user.id_token


def _extract_id_token(auth_result: dict) -> str:
    if "AuthenticationResult" in auth_result:
        token = auth_result["AuthenticationResult"].get("IdToken")
        if token:
            return token

    challenge = auth_result.get("ChallengeName")
    if challenge == "NEW_PASSWORD_REQUIRED":
        raise RuntimeError(
            "Cognito requires a new password before sign-in can complete. "
            "Set a permanent password in the app first."
        )
    if challenge:
        raise RuntimeError(f"Unsupported Cognito challenge: {challenge}")

    raise RuntimeError(f"Unexpected Cognito response: {json.dumps(auth_result)}")


def get_id_token(
    *,
    region: str,
    client_id: str,
    user_pool_id: str,
    username: str,
    password: str,
) -> str:
    try:
        return _extract_id_token(
            _password_auth(region, client_id, username, password)
        )
    except RuntimeError as error:
        message = str(error)
        if "USER_PASSWORD_AUTH" in message or "flow not enabled" in message.lower():
            return _srp_auth(user_pool_id, client_id, username, password)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description="Print Cognito ID token to stdout")
    parser.add_argument("--region", default="ap-south-1")
    parser.add_argument("--client-id", default="46865gj4jba5bp42cc04fo14k1")
    parser.add_argument("--user-pool-id", default="ap-south-1_vm19Xv95r")
    parser.add_argument("--username", required=True, help="Cognito email / username")
    parser.add_argument("--password", required=True)
    args = parser.parse_args()

    try:
        token = get_id_token(
            region=args.region,
            client_id=args.client_id,
            user_pool_id=args.user_pool_id,
            username=args.username,
            password=args.password,
        )
    except Exception as exc:  # noqa: BLE001 - CLI should surface any auth failure
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(token)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
