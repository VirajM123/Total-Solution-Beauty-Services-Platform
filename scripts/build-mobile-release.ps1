param([Parameter(Mandatory=$true)][ValidateSet('customer','worker')][string]$App)
$ErrorActionPreference = 'Stop'
function Assert-HttpsUrl([string]$Value, [string]$Name, [bool]$Api = $false) {
  $parsedReleaseUrl = $null
  if (![Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$parsedReleaseUrl) -or
      $parsedReleaseUrl.Scheme -ne 'https' -or $parsedReleaseUrl.UserInfo -or
      $parsedReleaseUrl.Query -or $parsedReleaseUrl.Fragment -or
      ($Api -and !$parsedReleaseUrl.AbsolutePath.EndsWith('/api/v1'))) {
    throw "Configure $Name as an HTTPS URL$(if ($Api) { ' ending /api/v1' })."
  }
}
Assert-HttpsUrl $env:API_BASE_URL 'API_BASE_URL' $true
$releaseArguments = @('build','appbundle','--release',"--dart-define=API_BASE_URL=$env:API_BASE_URL")
if ($App -eq 'customer') {
  $releaseArguments += @('-t','lib/main_prod.dart')
} else {
  Assert-HttpsUrl $env:WORKER_TERMS_URL 'WORKER_TERMS_URL'
  Assert-HttpsUrl $env:WORKER_PRIVACY_URL 'WORKER_PRIVACY_URL'
  $releaseArguments += @("--dart-define=WORKER_TERMS_URL=$env:WORKER_TERMS_URL", "--dart-define=WORKER_PRIVACY_URL=$env:WORKER_PRIVACY_URL")
}
Push-Location (Join-Path $PSScriptRoot "../apps/${App}_app")
try {
  & flutter.bat @releaseArguments
  if ($LASTEXITCODE -ne 0) { throw 'Release build failed. Check configuration and the intended signing identity.' }
} finally { Pop-Location }
