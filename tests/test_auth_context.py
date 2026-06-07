import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app" / "lambdas" / "unified"))

import auth_context  # noqa: E402


def test_partner_from_groups():
    event = {
        "requestContext": {
            "authorizer": {
                "jwt": {
                    "claims": {
                        "sub": "u1",
                        "email": "p@acme.com",
                        "cognito:groups": ["bayrelay-partners"],
                        "custom:partner_id": "PRT-acme",
                    }
                }
            }
        }
    }
    ctx = auth_context.from_event(event)
    assert ctx.is_partner
    assert ctx.partner_id == "PRT-acme"


def test_operator_from_groups():
    event = {
        "requestContext": {
            "authorizer": {
                "jwt": {
                    "claims": {
                        "sub": "u2",
                        "cognito:groups": "bayrelay-operators",
                    }
                }
            }
        }
    }
    ctx = auth_context.from_event(event)
    assert ctx.is_operator


def test_jwt_required_denies_unauthenticated(monkeypatch):
    monkeypatch.setenv("ENABLE_API_JWT_AUTH", "true")
    ctx = auth_context.from_event({})
    assert ctx.role == "public"
    assert auth_context.require_operator(ctx) is not None


def test_jwt_required_denies_claims_without_group(monkeypatch):
    monkeypatch.setenv("ENABLE_API_JWT_AUTH", "true")
    event = {
        "requestContext": {
            "authorizer": {
                "jwt": {
                    "claims": {
                        "sub": "u3",
                        "email": "legacy@example.com",
                    }
                }
            }
        }
    }
    ctx = auth_context.from_event(event)
    assert ctx.role == "public"
    assert auth_context.require_operator(ctx) is not None


def test_jwt_optional_elevates_public_to_operator(monkeypatch):
    monkeypatch.setenv("ENABLE_API_JWT_AUTH", "false")
    ctx = auth_context.from_event({})
    assert ctx.is_operator


def test_jwt_optional_legacy_claims_without_group(monkeypatch):
    monkeypatch.setenv("ENABLE_API_JWT_AUTH", "false")
    event = {
        "requestContext": {
            "authorizer": {
                "jwt": {
                    "claims": {"sub": "u4", "email": "legacy@example.com"}
                }
            }
        }
    }
    ctx = auth_context.from_event(event)
    assert ctx.is_operator
