# BayRelay — Proposal summary

**BayAreaLa8s** · Agentic B2B file transfer on AWS  
[bayareala8s.com](https://www.bayareala8s.com/) · himanshu.bhadra@bayareala8s.com · +1 925-758-1117

---

## Executive summary

**BayRelay** deploys in **your AWS account**: secure file exchange (S3 and SFTP), workflow orchestration, audit trails, and an **AI assistant** grounded in your runbooks. You retain data ownership and pay AWS directly. BayAreaLa8s delivers fixed-scope implementation—not multi-tenant hosting.

---

## Recommended path

| Step | Package | Investment |
|------|---------|------------|
| **1. Validate** | **PoC** (90 days) | **$24,000** |
| **2. Go live** | **Production Launch** | **$42,000** (or **$34,000** if you upgrade within 60 days of PoC) |
| **3. Operate** (optional) | **Care** retainer | **$3,500/month** (6-month minimum) |

**Your AWS costs (separate):** about **$1,500–$4,000** during PoC if the stack runs continuously; about **$800–$1,200/month** for always-on production (region and usage vary).

---

## What BayRelay includes

- REST API with **JWT + WAF** (Cognito operators)
- Transfer patterns: **S3↔S3**, **S3↔SFTP**, **SFTP↔S3**, **SFTP↔SFTP**
- **AWS Transfer Family** (inbound SFTP + connector)
- **Amazon Bedrock** agent + **knowledge base** (your policies and runbooks)
- **Terraform** infrastructure as code in your account
- Automated smoke test and written handoff

---

## PoC — $24,000 (90-day evaluation)

**Ideal for:** Technical validation, executive demo, security architecture review in a **sandbox AWS account**.

| Included | |
|----------|--|
| Full stack deploy in your AWS account | |
| Automated end-to-end smoke test | |
| Up to **10** knowledge-base documents | |
| **2** API operator accounts | |
| **14 days** hypercare (4 hours) | |
| Teardown at PoC end **or** upgrade to Production | |

**Timeline:** about **8–12 business days** from kickoff to handoff.

---

## Production Launch — $42,000

**Ideal for:** Production go-live after PoC—or direct launch when requirements are clear.

| Included | |
|----------|--|
| Everything required for production operations | |
| Up to **20** KB documents | |
| **3** Cognito operators | |
| Guidance to **publish** Bedrock agent alias | |
| **1** production partner connector (agreed design) | |
| **30 days** hypercare (8 hours) | |
| **2-hour** handoff session | |

**Upgrade credit:** **$8,000** off Production if you sign within **60 days** of completed PoC → **$34,000** total for Production.

---

## Why BayAreaLa8s

- **24+ years** cloud experience across AWS, Azure, and GCP  
- **Fixed-scope** delivery with clear acceptance criteria  
- Enterprise delivery experience; Silicon Valley based  
- **Your account, your data** — no vendor lock-in on hosting  

---

## Next steps

1. **30-minute discovery call** — region, partners, PoC vs direct Production  
2. **Signed PoC SOW** — we recommend starting with PoC in a dedicated AWS account  
3. **Kickoff** — access, Bedrock model enablement, deploy (~2 weeks to handoff)  

**Contact:** [himanshu.bhadra@bayareala8s.com](mailto:himanshu.bhadra@bayareala8s.com?subject=BayRelay%20PoC%20Proposal)

---

*BayRelay is a production-oriented reference implementation deployed via Infrastructure as Code. AWS service charges apply. Full terms in the Statement of Work.*
