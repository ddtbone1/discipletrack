# Provisions a church on a HOSTED Supabase project (DATABASE_CONSTRAINTS.md
# section 0). Locally, supabase/seed.sql does this on `npx supabase db reset`.
#
# All provisioning logic lives in the database function
# private.bootstrap_church(). This script only:
#   1. creates the initial trusted user through the GoTrue admin API
#      (confirmed, with full_name metadata so the profile trigger runs), and
#   2. calls the function over a direct database connection.
#
# The function is deliberately NOT reachable through PostgREST, so step 2
# needs psql and the database connection string, not the API.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\bootstrap_church.ps1 `
#     -SupabaseUrl https://<ref>.supabase.co `
#     -ServiceRoleKey $env:SUPABASE_SERVICE_ROLE_KEY `
#     -DbUrl "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres" `
#     -ChurchName "Bankal Seventh-day Adventist Church" `
#     -AdminEmail admin@example.org -AdminPassword <password> -AdminFullName "Admin Name"
#
# Omit -JoinCode to let the database generate one cryptographically; it is
# printed once at the end. -ChurchId defaults to a new UUID.

param(
    [Parameter(Mandatory = $true)] [string] $SupabaseUrl,
    [Parameter(Mandatory = $true)] [string] $ServiceRoleKey,
    [Parameter(Mandatory = $true)] [string] $DbUrl,
    [Parameter(Mandatory = $true)] [string] $ChurchName,
    [Parameter(Mandatory = $true)] [string] $AdminEmail,
    [Parameter(Mandatory = $true)] [string] $AdminPassword,
    [Parameter(Mandatory = $true)] [string] $AdminFullName,
    [string] $ChurchId = [guid]::NewGuid().ToString(),
    [string] $JoinCode = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    throw 'psql is required on PATH to call private.bootstrap_church().'
}

Write-Host "=== 1. Creating the initial user via the admin API ===" -ForegroundColor Cyan
$headers = @{ apikey = $ServiceRoleKey; Authorization = "Bearer $ServiceRoleKey" }
$body = @{
    email         = $AdminEmail
    password      = $AdminPassword
    email_confirm = $true
    user_metadata = @{ full_name = $AdminFullName }
} | ConvertTo-Json -Depth 3

try {
    $user = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/auth/v1/admin/users" `
        -Headers $headers -ContentType 'application/json' -Body $body
    $userId = $user.id
    Write-Host "   created user $userId"
} catch {
    # Re-runs: look the user up instead of failing.
    $list = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/auth/v1/admin/users?page=1&per_page=1000" -Headers $headers
    $existing = $list.users | Where-Object { $_.email -eq $AdminEmail } | Select-Object -First 1
    if (-not $existing) { throw }
    $userId = $existing.id
    Write-Host "   user already exists: $userId"
}

Write-Host "=== 2. Calling private.bootstrap_church() ===" -ForegroundColor Cyan
$codeArg = if ($JoinCode) { "'$JoinCode'" } else { 'null' }
$sql = "select private.bootstrap_church(p_church_id => '$ChurchId', p_name => `$q`$$ChurchName`$q`$, p_initial_user_id => '$userId', p_join_code => $codeArg);"
& psql "$DbUrl" -v ON_ERROR_STOP=1 -Atc $sql | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'bootstrap_church failed; see psql output above.' }

$code = & psql "$DbUrl" -Atc "select join_code from public.churches where id = '$ChurchId';"
Write-Host "`n   Church id:  $ChurchId" -ForegroundColor Green
Write-Host "   Join code:  $code" -ForegroundColor Green
Write-Host "   Give the join code to members. It is not shown in the app." -ForegroundColor DarkGray
