# Demo Place Seed

This folder contains a curated District 1 demo dataset for nearby scan.

## Files

- `demo-district-1-core.places.json`
  - Reviewable source dataset with the requested fields:
    - `id`
    - `name`
    - `normalizedName`
    - `category`
    - `lat`
    - `lng`
    - `address`
    - `sourceNote`
- `dynamodb/demo-district-1-core.batch-01.json`
- `dynamodb/demo-district-1-core.batch-02.json`
- `dynamodb/demo-district-1-core.batch-03.json`
  - Import-ready DynamoDB `batch-write-item` payloads for the `mapvibe-dev-places` table.

## Data policy

All places in this seed are curated fictional demo venues placed in a dense District 1 area.
They were manually created for product demos and nearby-scan UX coverage, not copied from
licensed business directories or third-party place databases.

## Rebuild

```bash
node scripts/build-demo-place-seed.cjs
```

To target a different table name:

```bash
MAPVIBE_PLACES_TABLE=mapvibe-prod-places node scripts/build-demo-place-seed.cjs
```

## Import

PowerShell helper:

```powershell
.\scripts\import-demo-place-seed.ps1
```

Manual AWS CLI import:

```bash
aws dynamodb batch-write-item --region ap-southeast-1 --request-items file://seeds/dynamodb/demo-district-1-core.batch-01.json
aws dynamodb batch-write-item --region ap-southeast-1 --request-items file://seeds/dynamodb/demo-district-1-core.batch-02.json
aws dynamodb batch-write-item --region ap-southeast-1 --request-items file://seeds/dynamodb/demo-district-1-core.batch-03.json
```
