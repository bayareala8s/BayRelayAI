# Statement of Work — BayRelay Production Launch (Customer AWS)

**Template for BayAreaLa8s engagements.** Customize bracketed fields before signature.

---

## Parties

| | |
|--|--|
| **Provider** | BayAreaLa8s (“Provider”) — [himanshu.bhadra@bayareala8s.com](mailto:himanshu.bhadra@bayareala8s.com), +1 925-758-1117 |
| **Customer** | [Customer legal name] (“Customer”) |
| **Effective date** | [Date] |

---

## 1. Purpose

Provider will deliver **BayRelay** — an agentic B2B file transfer platform on **Amazon Web Services (AWS)** — deployed entirely in **Customer’s AWS account**. Customer retains ownership of data, infrastructure, and AWS billing. Provider delivers implementation, configuration, validation, and knowledge transfer per this SOW.

---

## 2. Scope of work — Production Launch

### 2.1 Included deliverables

| # | Deliverable | Acceptance criteria |
|---|-------------|---------------------|
| 1 | **Infrastructure deployment** | Terraform apply in Customer account: API (JWT + WAF), Lambda, Step Functions, DynamoDB, S3, KMS, CloudWatch alarms |
| 2 | **Transfer Family (Phase 2)** | SFTP server + connector provisioned per agreed design (single demo/same-account connector unless Change Order) |
| 3 | **Knowledge base (Phase 3)** | OpenSearch Serverless + Bedrock KB; ingest of up to **[20]** curated documents supplied by Customer |
| 4 | **Bedrock agent** | Orchestrator agent deployed; Prepare + guidance to publish production alias |
| 5 | **Cognito operators** | Up to **[3]** API operator accounts created |
| 6 | **Automated smoke test** | Provider runs end-to-end smoke script; **exit code 0** on core flows (partner/endpoint registration, S3→S3, connector path if enabled, KB retrieval if enabled) |
| 7 | **Handoff package** | Written outputs (API URL, resource IDs, runbooks); 2-hour handoff session (remote) |
| 8 | **Hypercare** | **30 calendar days** email support, up to **8 hours** total (configuration questions, smoke re-run guidance) |

### 2.2 Out of scope (unless Change Order)

- Customer AWS account fees (compute, Transfer Family hourly, OpenSearch OCUs, Bedrock usage)
- Multi-tenant SaaS hosted by Provider
- Per-partner API keys / **operator or partner portal UI** → [Operator Portal MVP](SOW_OPERATOR_PORTAL_ADDON.md) from **$22k**
- 24/7 on-call or SLA-backed incident response
- Compliance attestations (SOC 2, HIPAA BAA, PCI) — available under separate engagement
- Additional partner SFTP connectors beyond **one (1)** production connector
- Custom application features not in the BayRelay reference repository
- Ongoing KB authoring beyond initial document ingest

---

## 3. Customer responsibilities

Customer will, in a timely manner:

1. Provide a dedicated AWS account (or OU) and **deployment access** (cross-account role or designated engineer).
2. Enable **Bedrock model access** in the deployment region for agreed foundation and embedding models.
3. Provide **Terraform remote state** (S3 + DynamoDB lock) or approve Provider-created state resources.
4. Supply **KB documents** (no secrets/credentials in KB content) and **Cognito operator** identities.
5. Designate a **single point of contact** and attend kickoff + handoff sessions.
6. Complete security / architecture review in Customer’s organization.
7. Pay **AWS invoices** directly to Amazon.

---

## 4. Assumptions

- Deployment region: **[us-west-2]** (or as agreed in writing).
- Provider deploys from repository version **[commit/tag]** at kickoff.
- Apply host can reach AWS APIs and, for Transfer connector setup, outbound SSH for host-key discovery **or** Customer supplies `trusted_host_keys`.
- Customer approves Terraform plan before apply (or delegates auto-approve in writing).
- Reference implementation disclaimer: software is production-oriented; Customer accepts operational ownership post-handoff.

---

## 5. Timeline

| Milestone | Target (business days from kickoff) |
|-----------|-------------------------------------|
| Kickoff + access confirmed | Day 0 |
| Preflight + terraform plan approved | Day 3–5 |
| Stack deployed + Phase 3 bootstrap | Day 8–15 |
| Smoke test pass + alias guidance | Day 12–18 |
| Handoff session | Day 15–20 |

Delays caused by Customer access, Bedrock approval, or security review extend timeline accordingly.

---

## 6. Fees and payment

| Item | Amount (USD) |
|------|----------------|
| **Production Launch (fixed)** | **$42,000** |
| **Optional Care** (if selected on Order Form) | **$3,500/month**, 6-month minimum |

**Payment schedule — Launch:**

- **50% ($21,000)** due upon SOW signature.
- **50% ($21,000)** due within **10 business days** of Handoff Acceptance (Section 7).

**Expenses:** None billed unless pre-approved in writing.

**AWS costs:** Billed by Amazon to Customer; Provider may supply non-binding estimates only.

---

## 7. Acceptance

**Handoff Acceptance** occurs when:

1. Smoke test (Section 2.1.6) has passed in Customer’s account; and  
2. Handoff package delivered; and  
3. Handoff session completed or Customer declines scheduling in writing after two proposed dates.

Customer has **5 business days** after handoff to report material non-conformance to scoped deliverables. Absent written rejection, deliverables are deemed accepted.

---

## 8. Change orders

Work outside Section 2.1 requires a signed Change Order. Indicative rates:

| Change | Fee (indicative) |
|--------|------------------|
| Additional partner SFTP connector | $6,000–$10,000 each |
| Additional KB document batch (ingest + test) | $2,500 per batch (up to 20 docs) |
| Extra Cognito operators (beyond 3) | $500 each |
| Extended hypercare (+8 hrs) | $1,200 per block |

---

## 9. Intellectual property

- **Pre-existing IP:** Provider retains ownership of BayRelay reference code, modules, and documentation; Customer receives a **non-exclusive, perpetual license** to use deployed artifacts in Customer’s AWS account for internal business purposes.
- **Customer data:** Customer owns all data in Customer’s AWS account.
- **Configurations:** Customer-specific `terraform.tfvars` and KB content remain Customer property.

---

## 10. Confidentiality

Each party will protect the other’s confidential information using reasonable care. Standard exclusions apply (public domain, independently developed, required by law).

---

## 11. Limitation of liability

Provider’s total liability under this SOW is limited to **fees paid** under this SOW. Neither party is liable for indirect, consequential, or lost-profits damages. Provider is not liable for Customer’s AWS charges, third-party outages, or misuse of API credentials.

---

## 12. Term and termination

- **Launch** completes at Handoff Acceptance or termination.
- Customer may terminate for convenience with **30 days’ written notice**; Provider is paid for work performed (time-and-materials at **$150/hr** capped at 50% of fixed fee) plus non-cancelable third-party costs.
- Either party may terminate for material breach if uncured within **15 business days**.

---

## 13. Optional — Care retainer (Order Form)

If selected:

| Item | Detail |
|------|--------|
| Fee | $3,500/month, 6-month minimum |
| Includes | Up to 12 hours/month: KB re-ingestion support, Terraform patch guidance, alarm review, one minor config change |
| Excludes | New connectors, new features, 24/7 on-call |

---

## Signatures

| Provider — BayAreaLa8s | Customer |
|------------------------|----------|
| Name: ___________________ | Name: ___________________ |
| Title: __________________ | Title: __________________ |
| Date: ___________________ | Date: ___________________ |

---

**Upgrade credit:** If Customer signs [Production Launch](SOW_PRODUCTION_LAUNCH_42K.md) within **60 days** of a completed BayRelay PoC, apply **$8,000** credit (Customer pays **$34,000** for Production instead of $42,000).

---

## Order Form summary (attach to proposal)

**SKU:** BayRelay Production Launch — Customer AWS  
**Fixed fee:** $42,000 USD (or **$34,000** with valid PoC upgrade credit)  
**Optional:** Care $3,500/mo × 6 months = $21,000  
**Estimated Customer AWS:** $800–$1,200/month (always-on, region-dependent; not guaranteed by Provider)

**See also:** [BayRelay PoC — $24,000](SOW_POC_24K.md) · [PRICING.md](PRICING.md)

**Provider contact:** [himanshu.bhadra@bayareala8s.com](mailto:himanshu.bhadra@bayareala8s.com) | [bayareala8s.com](https://www.bayareala8s.com/)
