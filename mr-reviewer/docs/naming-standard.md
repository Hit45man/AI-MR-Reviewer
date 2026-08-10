# Resource naming standard (template)

> Customize `{org}` and patterns for the bank. MR Reviewer cites this doc for naming findings.

## Universal rules

1. Lowercase `a-z`, `0-9`, hyphens only (unless AWS requires otherwise).
2. Always include `{org}` and `{env}`.
3. No customer names, account numbers, or PAN in resource names.
4. Build names from Terraform `locals` — do not hard-code full names.

## Environments

| Environment | Abbreviation |
|-------------|--------------|
| Development | `dev` |
| UAT | `uat` |
| Staging | `stg` |
| Production | `prod` |
| Shared platform | `shared` |

## Canonical pattern

```text
{org}-{env}-{region}-{workload}-{type}-{instance}
```

Example: `bnk-prod-euw1-payments-rds-01`

## Mandatory tags

| Key | Example |
|-----|---------|
| `env` | `prod` |
| `team` | `platform` |
| `workload` | `payments` |
| `cost-center` | `cc-1001` |
| `data-class` | `confidential` |
| `managed-by` | `terraform` |

## Reject

| Bad | Good |
|-----|------|
| `Prod_Payments_DB` | `bnk-prod-euw1-payments-rds-01` |
| Missing env | Include `dev` / `uat` / `prod` |
