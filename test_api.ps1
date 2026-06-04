# Set password
aws cognito-idp admin-set-user-password --user-pool-id ap-southeast-1_KSHDSpl6f --username testapi@fidee.com --password "TestApi@123" --permanent

# Get token
$authJson = aws cognito-idp initiate-auth --client-id 35jeemfqql648mt950s6bs3qli --auth-flow USER_PASSWORD_AUTH --auth-parameters USERNAME=testapi@fidee.com,PASSWORD=TestApi@123
$authObj = $authJson | ConvertFrom-Json
$token = $authObj.AuthenticationResult.IdToken

# Call API
$headers = @{
    "Authorization" = $token
}
$response = Invoke-RestMethod -Uri "https://92idnbsaoj.execute-api.ap-southeast-1.amazonaws.com/dev/places/nearby?lat=10.7738&lng=106.7035&radius=300" -Headers $headers -Method Get

$response | ConvertTo-Json -Depth 10
