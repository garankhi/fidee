# Get token
$authJson = aws cognito-idp initiate-auth --client-id 35jeemfqql648mt950s6bs3qli --auth-flow USER_PASSWORD_AUTH --auth-parameters USERNAME=testapi@fidee.com,PASSWORD=TestApi@123
$authObj = $authJson | ConvertFrom-Json
$token = $authObj.AuthenticationResult.IdToken
$headers = @{ "Authorization" = $token }

$base = "https://92idnbsaoj.execute-api.ap-southeast-1.amazonaws.com/dev"

# Test 1: GET pending
Write-Host "`n=== GET /admin/places/pending ===" -ForegroundColor Cyan
$r1 = Invoke-RestMethod -Uri "$base/admin/places/pending" -Headers $headers -Method Get
$r1 | ConvertTo-Json -Depth 10

# Test 2: GET candidate detail (first candidate from seed data)
Write-Host "`n=== GET /admin/places/candidates/{id} ===" -ForegroundColor Cyan
$candidateId = "b2000001-0001-0001-0001-000000000001"
$r2 = Invoke-RestMethod -Uri "$base/admin/places/candidates/$candidateId" -Headers $headers -Method Get
$r2 | ConvertTo-Json -Depth 10
