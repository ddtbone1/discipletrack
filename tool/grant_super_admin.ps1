# Grants or ends the platform SUPER_ADMIN role on a HOSTED Supabase project
# (ADR-022). Locally, supabase/seed.sql grants it to
# superadmin@discipletrack.local on `npx supabase db reset`.
#
# The account must already be registered (signed up and confirmed in the
# app, or created through the admin API). This script only calls the
# trusted database functions:
#   private.grant_platform_role(user_id, 'SUPER_ADMIN')
#   private.end_platform_role(user_id, 'SUPER_ADMIN')
# Both run in the service-role context and are NOT reachable through
# PostgREST, so this needs psql and the database connection string. No app
# user can grant the role: there is no client write path.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\grant_super_admin.ps1 `
#     -DbUrl "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres" `
#     -Email operator@example.org
#
#   Add -End to end the role instead. Rows are ended, never deleted, and
#   both actions are audited (PLATFORM_ROLE_GRANTED / PLATFORM_ROLE_ENDED).

param(
    [Parameter(Mandatory = $true)] [string] $DbUrl,
    [Parameter(Mandatory = $true)] [string] $Email,
    [switch] $End
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    throw 'psql is required on PATH to call private.grant_platform_role().'
}

# Dollar-quoted so the email cannot break out of the literal.
$emailLiteral = "`$e`$$Email`$e`$"

$userId = & psql "$DbUrl" -v ON_ERROR_STOP=1 -Atc "select id from auth.users where lower(email) = lower($emailLiteral);"
if ($LASTEXITCODE -ne 0) { throw 'Looking up the account failed; see psql output above.' }
if (-not $userId) { throw "No registered account uses $Email. Register it first." }

if ($End) {
    Write-Host "=== Ending SUPER_ADMIN for $Email ($userId) ===" -ForegroundColor Cyan
    $sql = "select private.end_platform_role('$userId', 'SUPER_ADMIN');"
} else {
    Write-Host "=== Granting SUPER_ADMIN to $Email ($userId) ===" -ForegroundColor Cyan
    $sql = "select private.grant_platform_role('$userId', 'SUPER_ADMIN');"
}

& psql "$DbUrl" -v ON_ERROR_STOP=1 -Atc $sql | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'The platform role call failed; see psql output above.' }

$active = & psql "$DbUrl" -Atc "select count(*) from public.platform_roles where user_id = '$userId' and role = 'SUPER_ADMIN' and ended_at is null;"
Write-Host "   Active SUPER_ADMIN rows for this account: $active" -ForegroundColor Green
