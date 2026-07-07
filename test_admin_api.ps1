# Get token
$authJson = aws cognito-idp initiate-auth --client-id 27tej2ge7ofoorpvabv4mh0hhj --auth-flow USER_PASSWORD_AUTH --auth-parameters USERNAME=testapi@fidee.com,PASSWORD=TestApi@123
$authObj = $authJson | ConvertFrom-Json
$token = $authObj.AuthenticationResult.IdToken
$headers = @{ "Authorization" = $token }

$base = "https://api-dev.fidee.site"

# Test: GET pending (full fields)
Write-Host "`n=== GET /admin/places/pending ===" -ForegroundColor Cyan
$r1 = Invoke-RestMethod -Uri "$base/admin/places/pending" -Headers $headers -Method Get
$r1 | ConvertTo-Json -Depth 10
