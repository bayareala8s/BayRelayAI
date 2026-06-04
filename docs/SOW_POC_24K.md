# Statement of Work — BayRelay Proof of Concept (Customer AWS)

**Template for BayAreaLa8s engagements.** Use for evaluation before Production Launch. Customize bracketed fields before signature.

**Related:** [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md) — full production scope.

---

## Parties

| | |
|--|--|
| **Provider** | BayAreaLa8s (“Provider”) — [himanshu.bhadra@bayareala8s.com](mailto:himanshu.bhadra@bayareala8s.com), +1 925-758-1117 |
| **Customer** | [Customer legal name] (“Customer”) |
| **Effective date** | [Date] |
| **PoC end date** | **[90]** calendar days after Handoff Acceptance (Section 7) |

---

## 1. Purpose

Provider will deploy **BayRelay** in **Customer’s AWS account** for a **time-boxed proof of concept** to validate technical fit, security posture, and business workflows. This PoC is not a production go-live unless Customer executes a separate Production Launch SOW or Change Order.

Customer retains AWS account ownership and pays AWS directly.

---

## 2. Scope of work — PoC

### 2.1 Included deliverables

| # | Deliverable | Acceptance criteria |
|---|-------------|---------------------|
| 1 | **Infrastructure deployment** | Terraform apply: API (JWT + WAF), Lambda, Step Functions, DynamoDB, S3, KMS, CloudWatch alarms |
| 2 | **Transfer Family (Phase 2)** | SFTP server + **one (1)** same-account / demo connector (not external partner production cutover) |
| 3 | **Knowledge base (Phase 3)** | Bedrock KB + ingest of up to **[10]** sample documents (Provider sample + Customer-supplied) |
| 4 | **Bedrock agent** | Agent deployed and Prepared; **draft alias (`TSTALIASID`) acceptable** for PoC |
| 5 | **Cognito operators** | Up to **[2]** operator accounts |
| 6 | **Automated smoke test** | Provider runs smoke script; **exit code 0** on S3→S3 and enabled Phase 2/3 paths |
| 7 | **PoC handoff** | Written outputs + **1-hour** remote walkthrough |
| 8 | **Hypercare** | **14 calendar days**, up to **4 hours** email support |
| 9 | **Teardown planning** | Written steps for `demo_stop.sh` or stack retention decision |

### 2.2 PoC limitations (not in scope)

- Published Bedrock production alias (Production Launch SOW)
- External partner SFTP production connectors (Change Order or Production Launch)
- More than **one (1)** connector or custom VPC networking
- More than **10** KB documents
- 24/7 support, SLA, or compliance attestations
- Production change-management or runbook ownership transfer beyond PoC handoff
- **AWS charges** (Customer responsibility; see Section 6)

### 2.3 Optional at PoC end (mutually agreed in writing)

| Option | Description |
|--------|-------------|
| **A. Teardown** | Provider runs destroy in Customer account (empty S3 + `terraform destroy`); included in PoC fee |
| **B. Retain stack** | Customer keeps resources; must accept ongoing AWS cost; upgrade via Production Launch |
| **C. Upgrade** | Apply **$8,000 credit** toward Production Launch if signed within **60 days** of PoC acceptance |

---

## 3. Customer responsibilities

Same as Production Launch SOW (access, Bedrock model enablement, state bucket, POC contact, security review for **non-production** account recommended).

**Strongly recommended:** Dedicated **PoC AWS account** or sandbox OU—not shared production.

---

## 4. Assumptions

- Deployment region: **[us-west-2]** (or as agreed).
- PoC duration: **90 days** from Handoff Acceptance unless extended by Change Order.
- Customer understands **Transfer Family and OpenSearch** incur hourly/OCU charges while stack is up.
- Teardown Option A scheduled within **5 business days** after PoC end date unless Upgrade signed.

---

## 5. Timeline

| Milestone | Target (business days from kickoff) |
|-----------|-------------------------------------|
| Kickoff + access | Day 0 |
| Deploy + bootstrap | Day 5–10 |
| Smoke pass + handoff | Day 8–12 |

---

## 6. Fees and payment

| Item | Amount (USD) |
|------|----------------|
| **PoC (fixed)** | **$24,000** |
| **Estimated Customer AWS (PoC window)** | **$1,500–$4,000** total if stack runs full 90 days with SFTP + KB (non-binding estimate) |

**Payment schedule — PoC:**

- **100% ($24,000)** due upon SOW signature, **or**
- **50% ($12,000)** at signature + **50% ($12,000)** at Handoff Acceptance (Customer choice; select on Order Form)

**Upgrade credit:** If Customer signs Production Launch within **60 days** of PoC acceptance, **$8,000** credit applied to the $42,000 Production fee → **$34,000** due for Production (one-time; not combinable with other discounts).

---

## 7. Acceptance

**PoC Handoff Acceptance** when smoke test passes and handoff package + session delivered. Customer has **3 business days** to report material non-conformance.

---

## 8. Change orders (PoC)

| Change | Indicative fee |
|--------|----------------|
| Extend PoC 30 days (support only, no redeploy) | $2,500 |
| External partner connector (one) | $5,000 |
| Skip teardown; convert in-place to Production | Credit per Section 6 + Production SOW delta |

---

## 9–12. Legal

Intellectual property, confidentiality, and limitation of liability: **same as** [SOW_PRODUCTION_LAUNCH_42K.md](SOW_PRODUCTION_LAUNCH_42K.md) Sections 9–11 (incorporated by reference).

---

## Signatures

| Provider — BayAreaLa8s | Customer |
|------------------------|----------|
| Name: ___________________ | Name: ___________________ |
| Title: __________________ | Title: __________________ |
| Date: ___________________ | Date: ___________________ |

---

## Order Form summary

| SKU | Fee |
|-----|-----|
| BayRelay PoC — Customer AWS | **$24,000** |
| BayRelay Production Launch (after PoC) | **$34,000** with upgrade credit, else **$42,000** |
| Optional Care (post-production only) | **$3,500/mo**, 6-month min |

**Teardown at PoC end:** ☐ Option A (included) ☐ Option B (retain) ☐ Option C (upgrade)
