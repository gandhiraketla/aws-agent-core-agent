# PowerShell script for AWS Cognito setup

# Get AWS region from environment variable or AWS CLI configuration
if (-not $env:AWS_REGION) {
    try {
        # Try to get region from AWS CLI configuration
        $Region = aws configure get region 2>$null
        if (-not $Region) {
            # Default to us-east-1 if no region is configured
            $Region = "us-east-1"
            Write-Host "Warning: No region configured. Using default: $Region" -ForegroundColor Yellow
        }
    }
    catch {
        $Region = "us-east-1"
        Write-Host "Warning: AWS CLI not found or configured. Using default: $Region" -ForegroundColor Yellow
    }
}
else {
    $Region = $env:AWS_REGION
}

Write-Host "Using AWS Region: $Region" -ForegroundColor Green
Write-Host ""

# Create User Pool
Write-Host "Creating User Pool..." -ForegroundColor Cyan
aws cognito-idp create-user-pool `
    --pool-name "DemoUserPool" `
    --policies '{\"PasswordPolicy\":{\"MinimumLength\":8}}' `
    --region "$Region" `
    --output json > pool.json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create user pool"
    exit 1
}

# Store Pool ID
$PoolData = Get-Content pool.json | ConvertFrom-Json
$PoolId = $PoolData.UserPool.Id
$env:POOL_ID = $PoolId

Write-Host "Pool ID: $PoolId" -ForegroundColor Green

# Create App Client
Write-Host "Creating App Client..." -ForegroundColor Cyan
aws cognito-idp create-user-pool-client `
    --user-pool-id $PoolId `
    --client-name "DemoClient" `
    --no-generate-secret `
    --explicit-auth-flows "ALLOW_USER_PASSWORD_AUTH" "ALLOW_REFRESH_TOKEN_AUTH" `
    --token-validity-units AccessToken=hours,IdToken=hours,RefreshToken=days `
    --access-token-validity 2 `
    --id-token-validity 2 `
    --refresh-token-validity 1 `
    --region "$Region" `
    --output json > client.json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create app client"
    exit 1
}

# Store Client ID
$ClientData = Get-Content client.json | ConvertFrom-Json
$ClientId = $ClientData.UserPoolClient.ClientId
$env:CLIENT_ID = $ClientId

Write-Host "CLIENT_ID: $ClientId" -ForegroundColor Green

# Create User
Write-Host "Creating test user..." -ForegroundColor Cyan
aws cognito-idp admin-create-user `
    --user-pool-id $PoolId `
    --username "testuser" `
    --temporary-password "Temp123!" `
    --region "$Region" `
    --message-action SUPPRESS `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create user"
    exit 1
}

# Set Permanent Password
Write-Host "Setting permanent password..." -ForegroundColor Cyan
aws cognito-idp admin-set-user-password `
    --user-pool-id $PoolId `
    --username "testuser" `
    --password "MyPassword123!" `
    --region "$Region" `
    --permanent `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set permanent password"
    exit 1
}

# Authenticate User
Write-Host "Authenticating user..." -ForegroundColor Cyan
aws cognito-idp initiate-auth `
    --client-id "$ClientId" `
    --auth-flow USER_PASSWORD_AUTH `
    --auth-parameters USERNAME='testuser',PASSWORD='MyPassword123!' `
    --region "$Region" `
    --output json > auth.json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to authenticate user"
    exit 1
}

# Display auth response
Write-Host "Authentication Response:" -ForegroundColor Cyan
Get-Content auth.json | ConvertFrom-Json | ConvertTo-Json -Depth 10

# Store Access Token
$AuthData = Get-Content auth.json | ConvertFrom-Json
$AccessToken = $AuthData.AuthenticationResult.AccessToken
$env:ACCESS_TOKEN = $AccessToken

Write-Host "ACCESS_TOKEN: $AccessToken" -ForegroundColor Green

# Export variables for use in other applications
$CognitoDiscoveryUrl = "https://cognito-idp.$Region.amazonaws.com/$PoolId/.well-known/openid-configuration"
$CognitoClientId = $ClientId
$CognitoAccessToken = $AccessToken

$env:COGNITO_DISCOVERY_URL = $CognitoDiscoveryUrl
$env:COGNITO_CLIENT_ID = $CognitoClientId
$env:COGNITO_ACCESS_TOKEN = $CognitoAccessToken

Write-Host ""
Write-Host "=========================================" -ForegroundColor Magenta
Write-Host "Cognito Setup Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Magenta
Write-Host "Cognito Discovery URL: $CognitoDiscoveryUrl" -ForegroundColor White
Write-Host "App Client ID: $CognitoClientId" -ForegroundColor White
Write-Host "Access Token: $CognitoAccessToken" -ForegroundColor White
Write-Host "=========================================" -ForegroundColor Magenta
Write-Host ""

# Clean up credential files for security
Write-Host "Cleaning up credential files..." -ForegroundColor Yellow
try {
    Remove-Item -Path "pool.json", "client.json", "auth.json" -Force -ErrorAction SilentlyContinue
    Write-Host "Credential files removed for security." -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not remove some credential files." -ForegroundColor Yellow
}
Write-Host "=========================================" -ForegroundColor Magenta