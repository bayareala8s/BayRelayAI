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
