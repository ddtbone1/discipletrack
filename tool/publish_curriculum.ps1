# Publishes the curriculum definition to a church on a HOSTED Supabase
# project (ADR-010 decision 2, ADR-019). Locally, `npx supabase db reset`
# does this through supabase/seed_curriculum.sql.
#
# All publishing logic lives in public.publish_curriculum(), which only
# service_role and the database owner may execute. Like
# tool/bootstrap_church.ps1, this script calls it over a direct database
# connection with psql.
#
# ADR-019: METADATA is the only level allowed until permission to
# reproduce the curriculum is recorded. A FULL publication requires
# -LicenceReference (the database refuses it otherwise), and its
# definition must come from outside the repository unless the licence
# allows committing it.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\publish_curriculum.ps1 `
#     -DbUrl "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres" `
#     -ChurchId <church uuid> -PublishedBy <profile uuid of the publishing admin>

param(
    [Parameter(Mandatory = $true)] [string] $DbUrl,
    [Parameter(Mandatory = $true)] [string] $ChurchId,
    [Parameter(Mandatory = $true)] [string] $PublishedBy,
    [string] $DefinitionPath = "$PSScriptRoot\..\supabase\curriculum\journey-metadata.json",
    [ValidateSet('METADATA', 'FULL')] [string] $ContentLevel = 'METADATA',
    [string] $LicenceReference = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    throw 'psql is required on PATH to call public.publish_curriculum().'
}
if ($ContentLevel -eq 'FULL' -and [string]::IsNullOrWhiteSpace($LicenceReference)) {
    throw 'A FULL publication needs -LicenceReference (ADR-019 decision 3).'
}

$definition = [IO.File]::ReadAllText((Resolve-Path $DefinitionPath))
$tag = '$curriculum$'
if ($definition.Contains($tag)) { throw "The definition contains $tag." }
$licence = if ([string]::IsNullOrWhiteSpace($LicenceReference)) { 'null' } else { "'" + $LicenceReference.Replace("'", "''") + "'" }

$sql = @"
select * from public.publish_curriculum(
  '$ChurchId',
  $tag$definition$tag::jsonb,
  '$ContentLevel',
  $licence,
  '$PublishedBy'
);
"@

# UTF-8 without a byte order mark, so psql reads the JSON verbatim.
$file = [IO.Path]::GetTempFileName()
try {
    [IO.File]::WriteAllText($file, $sql, (New-Object Text.UTF8Encoding($false)))
    psql $DbUrl -v ON_ERROR_STOP=1 -X -q -f $file
    if ($LASTEXITCODE -ne 0) { throw "psql failed with exit code $LASTEXITCODE." }
}
finally {
    Remove-Item $file -ErrorAction SilentlyContinue
}
