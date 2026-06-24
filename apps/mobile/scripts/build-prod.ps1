param(
  [string]$StackName = 'Fidee-prod',
  [string]$BuildName = '1.0.0',
  [int]$BuildNumber = 1,
  [string]$GoongMaptilesKey = $env:GOONG_MAPTILES_KEY,
  [string]$GoongApiKey = $env:GOONG_API_KEY,
  [string]$GoongStyleUrl = $env:GOONG_STYLE_URL,
  [string]$RevenueCatAndroidApiKey = $env:REVENUECAT_ANDROID_API_KEY,
  [string]$RevenueCatIosApiKey = $env:REVENUECAT_IOS_API_KEY
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($GoongStyleUrl)) {
  $GoongStyleUrl = 'https://tiles.goong.io/assets/goong_map_web.json'
}

function Get-StackOutput {
  param(
    [Parameter(Mandatory = $true)][string]$Key,
    [bool]$Required = $true
  )

  $match = $script:StackOutputs | Where-Object { $_.OutputKey -eq $Key } | Select-Object -First 1
  if ($null -eq $match -or [string]::IsNullOrWhiteSpace($match.OutputValue)) {
    if ($Required) {
      throw "CloudFormation output '$Key' was not found in stack '$StackName'."
    }
    return $null
  }

  return $match.OutputValue.Trim()
}

function Add-DartDefine {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowNull()][string]$Value,
    [bool]$Required = $true
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    if ($Required) {
      throw "Missing required build value '$Name'. Set it as a parameter or environment variable."
    }
    return
  }

  $script:DartDefines += "--dart-define=$Name=$($Value.Trim())"
}

$mobileRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $mobileRoot

try {
  Write-Host "Reading CloudFormation outputs from $StackName..."
  $outputsJson = & aws cloudformation describe-stacks `
    --stack-name $StackName `
    --query 'Stacks[0].Outputs' `
    --output json

  if ($LASTEXITCODE -ne 0) {
    throw "aws cloudformation describe-stacks failed for stack '$StackName'."
  }

  $script:StackOutputs = $outputsJson | ConvertFrom-Json
  if ($null -eq $script:StackOutputs) {
    throw "Stack '$StackName' returned no CloudFormation outputs."
  }

  $apiBaseUrl = Get-StackOutput 'CustomApiUrl' $false
  if ([string]::IsNullOrWhiteSpace($apiBaseUrl)) {
    $apiBaseUrl = Get-StackOutput 'ApiUrl'
  }
  $apiBaseUrl = $apiBaseUrl.TrimEnd('/')

  $appSyncGraphqlUrl = Get-StackOutput 'FriendRealtimeGraphqlUrl'
  $appSyncRealtimeUrl = $appSyncGraphqlUrl `
    -replace '^https://', 'wss://' `
    -replace 'appsync-api', 'appsync-realtime-api'

  $script:DartDefines = @()
  Add-DartDefine 'API_BASE_URL' $apiBaseUrl
  Add-DartDefine 'COGNITO_USER_POOL_ID' (Get-StackOutput 'UserPoolId')
  Add-DartDefine 'COGNITO_CLIENT_ID' (Get-StackOutput 'UserPoolClientId')
  Add-DartDefine 'APPSYNC_GRAPHQL_URL' $appSyncGraphqlUrl
  Add-DartDefine 'APPSYNC_REALTIME_URL' $appSyncRealtimeUrl
  Add-DartDefine 'GOONG_MAPTILES_KEY' $GoongMaptilesKey
  Add-DartDefine 'GOONG_API_KEY' $GoongApiKey
  Add-DartDefine 'GOONG_STYLE_URL' $GoongStyleUrl
  Add-DartDefine 'REVENUECAT_ANDROID_API_KEY' $RevenueCatAndroidApiKey
  Add-DartDefine 'REVENUECAT_IOS_API_KEY' $RevenueCatIosApiKey $false

  $flutterArgs = @(
    'build',
    'appbundle',
    '--release',
    '--build-name',
    $BuildName,
    '--build-number',
    $BuildNumber.ToString()
  ) + $script:DartDefines

  Write-Host "Building Android App Bundle with prod CDK outputs..."
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw 'flutter build appbundle failed.'
  }
} finally {
  Pop-Location
}