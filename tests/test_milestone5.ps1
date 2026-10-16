<#
.SYNOPSIS
  Milestone 5 Test Runner: Full Theme Verification & Native Integrity
.DESCRIPTION
  Executes tests/verify-theme.ps1 and asserts zero test failures for M5 sign-off.
#>

[CmdletBinding()]
param(
  [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                MILESTONE 5 TEST EXECUTION: FULL THEME INTEGRITY                " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$verifyScript = Join-Path $ProjectRoot "tests/verify-theme.ps1"
if (-not (Test-Path $verifyScript)) {
  Write-Host "[FAIL] Verification suite $verifyScript not found!" -ForegroundColor Red
  exit 1
}

$proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$verifyScript`"", "-ProjectRoot", "`"$ProjectRoot`"" -NoNewWindow -Wait -PassThru

if ($proc.ExitCode -eq 0) {
  Write-Host "`n[MILESTONE 5 PASS] Full theme verification suite executed successfully with exit code 0." -ForegroundColor Green
  exit 0
} else {
  Write-Host "`n[MILESTONE 5 FAIL] Verification suite failed with exit code $($proc.ExitCode)!" -ForegroundColor Red
  exit $proc.ExitCode
}
