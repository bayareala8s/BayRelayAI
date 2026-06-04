# BayRelay pricing (customer AWS)

Public anchor pricing for [BayAreaLa8s](https://www.bayareala8s.com/) proposals and website. AWS fees are **always** paid by the customer to Amazon.

---

## Packages

| Package | Best for | Fixed fee (USD) | SOW |
|---------|----------|-----------------|-----|
| **PoC** | 90-day evaluation, executive demo, technical validation | **$24,000** | [SOW_POC_24K.md](SOW_POC_24K.md) |
| **Production Launch** | Go-live in customer account, full handoff | **$42,000** | [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md) |
| **PoC → Production upgrade** | PoC accepted within 60 days | **$34,000** | Production SOW + $8k credit |
| **Accelerator** | Customer self-deploys; workshops only | **$12,000** | Statement of work (lightweight) |
| **Care** (optional, post-production) | KB refresh, patches, alarm review | **$3,500/mo** (6-mo min) | Order Form |
| **Operator Portal MVP** (change order) | Web UI on existing API + Cognito | **$22,000** | [SOW_OPERATOR_PORTAL_ADDON.md](SOW_OPERATOR_PORTAL_ADDON.md) |
| **Consulting** | Reviews, extra connectors, compliance help | **$90/hr** | Time & materials |

---

## What changes between PoC and Production

| Item | PoC ($24k) | Production ($42k) |
|------|------------|-------------------|
| Duration intent | 90-day evaluation | Ongoing production |
| KB documents | Up to 10 | Up to 20 |
| Cognito operators | 2 | 3 |
| Bedrock alias | Draft OK | Published alias required |
| Hypercare | 14 days / 4 hrs | 30 days / 8 hrs |
| Handoff session | 1 hour | 2 hours |
| Partner SFTP (external) | Out of scope | 1 connector included |
| Teardown | Included option | N/A (retain stack) |
| Upgrade credit | — | $8k if PoC → Prod in 60 days |

---

## Customer AWS costs (estimates, us-west-2)

| Profile | Monthly (24/7) | PoC 90-day total (approx.) |
|---------|----------------|----------------------------|
| **Full stack** (SFTP + KB + light Bedrock) | $800–$1,200 | $1,500–$4,000 |
| **Demo windows only** (`demo_stop` between meetings) | Pay per day stack is up | $300–$800 |

Use `demo_stop.sh` between internal demos to minimize AWS spend.

---

## Scope levers (discount without new SKU)

| Reduce price | Remove | Savings (indicative) |
|--------------|--------|----------------------|
| PoC Lite (custom quote) | Transfer + KB | ~$6k off PoC |
| Production S3-only | `enable_transfer_family = false` | ~$8k off Launch |
| No RAG | `enable_bedrock_vector_kb = false` | ~$5k off Launch |

**Add-ons (increase scope):** Operator Portal MVP **$22k** · Production + Portal bundle **$58k** (see [OPERATOR_PORTAL_MVP.md](OPERATOR_PORTAL_MVP.md)).

Do not discount below **$18,000** PoC or **$32,000** Production without written scope reduction.

---

## Payment terms (default)

| Package | Terms |
|---------|--------|
| PoC | 100% at signature **or** 50/50 at signature / acceptance |
| Production | 50% at signature, 50% at handoff |
| Care | Monthly in advance |

---

## Sales flow (recommended)

```text
Discovery → Quote PoC ($24k) → PoC handoff → Decision
    → Production ($34k w/ credit or $42k) → Optional Care ($3.5k/mo)
```

---

## Website copy (short)

> **PoC from $24,000** · **Production launch from $42,000** · AWS costs separate · **$8,000 upgrade credit** when you go to production within 60 days of PoC.

---

## Related docs

- [CUSTOMER_AWS_DEPLOYMENT.md](CUSTOMER_AWS_DEPLOYMENT.md)
- [website/BAYRELAY_MINI_PRODUCT_PAGE.md](website/BAYRELAY_MINI_PRODUCT_PAGE.md)
- [DEMO_LIFECYCLE.md](DEMO_LIFECYCLE.md)
