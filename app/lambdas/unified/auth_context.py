"""JWT role context for operator vs partner API access."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

OPERATOR_GROUP = "bayrelay-operators"
PARTNER_GROUP = "bayrelay-partners"


@dataclass(frozen=True)
class AuthContext:
    role: str  # operator | partner | public
    sub: str
    email: str
    username: str
    partner_id: str | None
    groups: tuple[str, ...]

    @property
    def is_operator(self) -> bool:
        return self.role == "operator"

    @property
    def is_partner(self) -> bool:
        return self.role == "partner"


def _parse_groups(raw: Any) -> tuple[str, ...]:
    if raw is None:
        return ()
    if isinstance(raw, list):
        return tuple(str(g) for g in raw)
    if isinstance(raw, str):
        if raw.startswith("[") and raw.endswith("]"):
            inner = raw[1:-1].strip()
            if not inner:
                return ()
            return tuple(p.strip().strip('"') for p in inner.split(","))
        return (raw,)
    return (str(raw),)


def from_event(event: dict[str, Any]) -> AuthContext:
    """Build auth context from API Gateway HTTP API JWT authorizer claims."""
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
        or {}
    )
    groups = _parse_groups(claims.get("cognito:groups"))
    partner_id = (claims.get("custom:partner_id") or "").strip() or None
    email = (claims.get("email") or claims.get("cognito:username") or "").strip()
    username = (claims.get("cognito:username") or email or "").strip()
    sub = (claims.get("sub") or "").strip()

    jwt_required = os.environ.get("ENABLE_API_JWT_AUTH", "true").lower() in ("1", "true", "yes")

    if OPERATOR_GROUP in groups:
        role = "operator"
    elif PARTNER_GROUP in groups:
        role = "partner"
    elif claims and not jwt_required:
        # Legacy demo users without groups — operator only when JWT is optional.
        role = "operator"
    else:
        role = "public"

    if not jwt_required and role == "public":
        role = "operator"

    return AuthContext(
        role=role,
        sub=sub,
        email=email,
        username=username,
        partner_id=partner_id,
        groups=groups,
    )


def forbid(message: str = "forbidden") -> dict[str, Any]:
    from bayrelay import errors as err

    return {"ok": False, "status_code": 403, "body": {"error": err.VALIDATION_ERROR, "message": message}}


def require_operator(ctx: AuthContext) -> dict[str, Any] | None:
    if not ctx.is_operator:
        return forbid("operator role required")
    return None


def require_partner_or_operator(ctx: AuthContext) -> dict[str, Any] | None:
    if ctx.role not in ("operator", "partner"):
        return forbid("authentication required")
    return None


def enforce_partner_scope(ctx: AuthContext, partner_id: str) -> dict[str, Any] | None:
    if ctx.is_operator:
        return None
    if ctx.is_partner and ctx.partner_id and ctx.partner_id == partner_id:
        return None
    return forbid("partner scope violation")


def partner_id_for_create(ctx: AuthContext, body_partner_id: str | None) -> tuple[str | None, dict[str, Any] | None]:
    """Partners may only act on their own partner_id."""
    if ctx.is_operator:
        return body_partner_id, None
    if ctx.is_partner:
        if not ctx.partner_id:
            return None, forbid("partner not provisioned — complete onboarding first")
        if body_partner_id and body_partner_id != ctx.partner_id:
            return None, forbid("cannot use a different partner_id")
        return ctx.partner_id, None
    return None, forbid("authentication required")
