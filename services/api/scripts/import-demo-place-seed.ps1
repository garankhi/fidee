param(
  [string]$Region = "ap-southeast-1",
  [string]$TableName = "mapvibe-dev-places"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Resolve-Path (Join-Path $scriptDir "..")
$seedsDir = Join-Path $projectDir "seeds"
$chunksDir = Join-Path $seedsDir "dynamodb"

Write-Host "Rebuilding demo seed payloads for table $TableName..."
$env:MAPVIBE_PLACES_TABLE = $TableName
node (Join-Path $scriptDir "build-demo-place-seed.cjs") | Out-Host

$batchFiles = Get-ChildItem -Path $chunksDir -Filter "demo-district-1-core.batch-*.json" | Sort-Object Name

foreach ($batchFile in $batchFiles) {
  Write-Host "Importing $($batchFile.Name) into $TableName..."
  aws dynamodb batch-write-item --region $Region --request-items "file://$($batchFile.FullName)"
}

Write-Host "Demo place seed import completed."
