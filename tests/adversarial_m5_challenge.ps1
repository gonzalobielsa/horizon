# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 5 Adversarial Challenge & Stress-Test Suite
# Reviewer: reviewer_m5_1 (Reviewer & Adversarial Critic)
# Target: tests/verify-theme.ps1, tests/test_milestone5.ps1, Milestone 5 Invariants
# ==============================================================================

[CmdletBinding()]
param(
  [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$totalChecks = 0
$passedChecks = 0
$failedChecks = 0
$criticalIssues = @()

function Assert-Check([string]$Name, [bool]$Condition, [string]$Detail = "") {
  $script:totalChecks++
  if ($Condition) {
    $script:passedChecks++
    Write-Host "  [PASS] $Name" -ForegroundColor Green
  } else {
    $script:failedChecks++
    $msg = "  [FAIL] ${Name}: $Detail"
    $script:criticalIssues += $msg
    Write-Host $msg -ForegroundColor Red
  }
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "       MILESTONE 5 ADVERSARIAL CHALLENGE & FALSIFIABILITY AUDIT                 " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Target: tests/verify-theme.ps1 & Native Theme Integrity"
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC`n"

# ------------------------------------------------------------------------------
# 1. Forensic Integrity & Anti-Tamper Checks on verify-theme.ps1
# ------------------------------------------------------------------------------
Write-Host "--- 1. Forensic Integrity & Facade Implementation Audit ---" -ForegroundColor Yellow

$verifyScriptPath = Join-Path $ProjectRoot "tests/verify-theme.ps1"
Assert-Check "verify-theme.ps1 exists" (Test-Path $verifyScriptPath) "Script missing"
$verifyScriptContent = Get-Content -LiteralPath $verifyScriptPath -Raw

# Check 1.1: Ensure test results are not hardcoded
$hasHardcodedPass = [regex]::IsMatch($verifyScriptContent, '\$totalPassed\s*=\s*\d{2,};')
Assert-Check "No hardcoded initial pass count in verify-theme.ps1" (-not $hasHardcodedPass) "Detected hardcoded totalPassed assignment!"

$hasBypassedExit = [regex]::IsMatch($verifyScriptContent, 'exit\s+0\s*#\s*bypass', 'IgnoreCase')
Assert-Check "No early exit 0 bypasses" (-not $hasBypassedExit) "Detected early bypass exit!"

# Check 1.2: Ensure error counting is active
$incrementsFail = [regex]::IsMatch($verifyScriptContent, '\$script:totalFailed\+\+')
Assert-Check "Report-Fail actively increments totalFailed" ($incrementsFail) "Report-Fail does not increment error count"

# Check 1.3: Ensure exit code reflects failures
$exitsOnError = [regex]::IsMatch($verifyScriptContent, 'if\s*\(\$totalFailed\s*-gt\s*0\)\s*\{[\s\S]*?exit\s+1')
Assert-Check "verify-theme.ps1 exits with code 1 upon failure" ($exitsOnError) "Script does not exit 1 on totalFailed > 0"

# ------------------------------------------------------------------------------
# 2. Suite 1 Falsifiability: Trailing Commas & Corrupted JSON
# ------------------------------------------------------------------------------
Write-Host "`n--- 2. Suite 1 Falsifiability: Trailing Commas & JSON Invariants ---" -ForegroundColor Yellow

$trailingCommaRegex = ',\s*[}\]]'
$cleanStripRegex = '(?m)^\s*//.*$'

# Negative Test 2.1: Trailing comma in object
$badJson1 = '{"name": "Heravyn", "category": "Pilates",}'
$clean1 = [regex]::Replace($badJson1, '^\s*/\*[\s\S]*?\*/\s*', '')
$clean1 = [regex]::Replace($clean1, $cleanStripRegex, '')
$tcDetected1 = [regex]::IsMatch($clean1, $trailingCommaRegex)
Assert-Check "Suite 1 detects trailing comma in JSON object: { ... , }" ($tcDetected1) "Trailing comma regex failed to detect defect"

# Negative Test 2.2: Trailing comma in array
$badJson2 = '{"items": ["dumbbell", "kettlebell",]}'
$clean2 = [regex]::Replace($badJson2, '^\s*/\*[\s\S]*?\*/\s*', '')
$clean2 = [regex]::Replace($clean2, $cleanStripRegex, '')
$tcDetected2 = [regex]::IsMatch($clean2, $trailingCommaRegex)
Assert-Check "Suite 1 detects trailing comma in JSON array: [ ... , ]" ($tcDetected2) "Trailing comma regex failed in array"

# Negative Test 2.3: Unclosed multiline comment block
$badJson3 = "/* Auto-generated header without closing `n {`"name`": `"test`"}"
$unclosedCommentDetected = ($badJson3 -match '^\s*/\*' -and $badJson3 -notmatch '^\s*/\*[\s\S]*?\*/')
Assert-Check "Suite 1 detects unclosed multiline comment block" ($unclosedCommentDetected) "Unclosed comment check failed"

# Positive Test 2.4: Real theme JSON file count & trailing comma check
$allJsonFiles = Get-ChildItem -Path $ProjectRoot -Recurse -Filter "*.json" |
  Where-Object { $_.FullName -notmatch '[\\/]\.git' -and $_.FullName -notmatch '[\\/]\.agents' }
Assert-Check "Total theme JSON files exactly equals 75" ($allJsonFiles.Count -eq 75) "Found $($allJsonFiles.Count) JSON files"

$realTrailingCommaCount = 0
$realParseErrorCount = 0
foreach ($jf in $allJsonFiles) {
  $raw = Get-Content -LiteralPath $jf.FullName -Raw
  $clean = [regex]::Replace($raw, '^\s*/\*[\s\S]*?\*/\s*', '')
  $clean = [regex]::Replace($clean, '(?m)^\s*//.*$', '')
  if ([regex]::IsMatch($clean, $trailingCommaRegex)) { $realTrailingCommaCount++ }
  try {
    $null = ConvertFrom-Json -InputObject $clean -ErrorAction Stop
  } catch {
    $realParseErrorCount++
  }
}
Assert-Check "Zero trailing commas across all 75 real theme JSON files" ($realTrailingCommaCount -eq 0) "Found $realTrailingCommaCount trailing commas"
Assert-Check "Zero syntax errors across all 75 real theme JSON files" ($realParseErrorCount -eq 0) "Found $realParseErrorCount parse errors"

# ------------------------------------------------------------------------------
# 3. Suite 2 Falsifiability: Liquid LIFO Stack Parser
# ------------------------------------------------------------------------------
Write-Host "`n--- 3. Suite 2 Falsifiability: Liquid LIFO Tag Balancing ---" -ForegroundColor Yellow

$tagRegex = [regex]'\{%-?\s*(?<isEnd>end)?(?<tag>if|unless|for|case|capture|form|paginate|schema|style|stylesheet|javascript)\b([\s\S]*?)-?%\}'

function Test-LiquidString([string]$liquidCode) {
  $clean = [regex]::Replace($liquidCode, '\{%-?\s*comment\s*-?%\}([\s\S]*?)\{%-?\s*endcomment\s*-?%\}', '')
  $clean = [regex]::Replace($clean, '\{%-?\s*doc\s*-?%\}([\s\S]*?)\{%-?\s*enddoc\s*-?%\}', '')
  $clean = [regex]::Replace($clean, '\{%-?\s*raw\s*-?%\}([\s\S]*?)\{%-?\s*endraw\s*-?%\}', '')
  $matches = $tagRegex.Matches($clean)
  $stack = New-Object System.Collections.Generic.Stack[string]
  $errors = @()

  foreach ($m in $matches) {
    $tag = $m.Groups['tag'].Value
    $isEnd = $m.Groups['isEnd'].Success
    if ($isEnd) {
      if ($stack.Count -eq 0) {
        $errors += "Unexpected close tag {% end$tag %}"
      } else {
        $top = $stack.Pop()
        if ($top -ne $tag) {
          $errors += "Mismatched close tag {% end$tag %}, expected {% end$top %}"
        }
      }
    } else {
      $stack.Push($tag)
    }
  }
  while ($stack.Count -gt 0) {
    $errors += "Unclosed open tag {% $($stack.Pop()) %}"
  }
  if ($errors.Count -eq 0) { return @() }
  return ,$errors
}

# Negative Test 3.1: Unclosed tag
$unclosedErrors = @(Test-LiquidString "{% if product.available %}<div>Available</div>")
Assert-Check "Suite 2 catches unclosed {% if %} tag" ($unclosedErrors.Count -gt 0 -and ($unclosedErrors -match "Unclosed").Count -gt 0) "Failed to catch unclosed tag"

# Negative Test 3.2: Mismatched tag
$mismatchErrors = @(Test-LiquidString "{% for item in items %}{% endif %}")
Assert-Check "Suite 2 catches mismatched {% for %} ... {% endif %}" ($mismatchErrors.Count -gt 0 -and ($mismatchErrors -match "Mismatched").Count -gt 0) "Failed to catch mismatched tag"

# Negative Test 3.3: Unexpected close tag
$unexpectedCloseErrors = @(Test-LiquidString "<div>Some text</div>{% endif %}")
Assert-Check "Suite 2 catches unexpected closing {% endif %}" ($unexpectedCloseErrors.Count -gt 0 -and ($unexpectedCloseErrors -match "Unexpected").Count -gt 0) "Failed to catch unexpected tag"

# Positive Test 3.4: Commented-out unclosed tag inside comment block
$commentedTagErrors = @(Test-LiquidString "{% comment %}{% if broken %}{% endcomment %}")
Assert-Check "Suite 2 ignores unclosed tags inside comment blocks" ($commentedTagErrors.Count -eq 0) "Comment stripping failed"

# Positive Test 3.5: Raw block with unclosed tag
$rawTagErrors = @(Test-LiquidString "{% raw %}{% if vue_template %}{% endraw %}")
Assert-Check "Suite 2 ignores tags inside raw blocks" ($rawTagErrors.Count -eq 0) "Raw block stripping failed"

# Positive Test 3.6: All 282 Liquid files in repo
$allLiquidFiles = Get-ChildItem -Path $ProjectRoot -Recurse -Filter "*.liquid" |
  Where-Object { $_.FullName -notmatch '[\\/]\.git' -and $_.FullName -notmatch '[\\/]\.agents' }
Assert-Check "Total theme Liquid files exactly equals 282" ($allLiquidFiles.Count -eq 282) "Found $($allLiquidFiles.Count) Liquid files"

$realLiquidFailures = 0
foreach ($lf in $allLiquidFiles) {
  $raw = Get-Content -LiteralPath $lf.FullName -Raw
  $errs = @(Test-LiquidString $raw)
  if ($errs.Count -gt 0) {
    $realLiquidFailures++
  }
}
Assert-Check "Strict LIFO tag balancing passes for ALL 282 real Liquid files" ($realLiquidFailures -eq 0) "Found $realLiquidFailures liquid files with errors"

# ------------------------------------------------------------------------------
# 4. Suite 3 Falsifiability: Platform Hooks & Invariants
# ------------------------------------------------------------------------------
Write-Host "`n--- 4. Suite 3 Falsifiability: Platform Hooks & Invariants ---" -ForegroundColor Yellow

# Negative Test 4.1: Missing hook detection
$dummyHtml = "<html><head><title>No hooks</title></head><body><h1>Hello</h1></body></html>"
$hook1Matches = [regex]::IsMatch($dummyHtml, '\{\{\s*content_for_header\s*\}\}')
Assert-Check "Suite 3 hook regex correctly rejects missing content_for_header" (-not $hook1Matches) "False positive on missing hook"

# Positive Test 4.2: Direct verification of all 14 required hooks in theme files
$hooksToCheck = @(
  @{ File = "layout/theme.liquid"; Pattern = '\{\{\s*content_for_header\s*\}\}'; Desc = "content_for_header" },
  @{ File = "layout/theme.liquid"; Pattern = '\{\{\s*content_for_layout\s*\}\}'; Desc = "content_for_layout" },
  @{ File = "layout/theme.liquid"; Pattern = '\{%-?\s*sections\s+[\x27\x22]header-group[\x27\x22]\s*-?%\}'; Desc = "header-group container" },
  @{ File = "layout/theme.liquid"; Pattern = '\{%-?\s*sections\s+[\x27\x22]footer-group[\x27\x22]\s*-?%\}'; Desc = "footer-group container" },
  @{ File = "layout/theme.liquid"; Pattern = '\{%-?\s*render\s+[\x27\x22]cart-drawer[\x27\x22]'; Desc = "cart-drawer render" },
  @{ File = "layout/theme.liquid"; Pattern = '\{%-?\s*render\s+[\x27\x22]search-modal[\x27\x22]'; Desc = "search-modal render" },
  @{ File = "sections/cart-drawer-section.liquid"; Pattern = '\{%-?\s*render\s+[\x27\x22]cart-drawer[\x27\x22]'; Desc = "SRA cart-drawer" },
  @{ File = "sections/predictive-search.liquid"; Pattern = 'id=[\x27\x22]predictive-search-results[\x27\x22]'; Desc = "predictive search id" },
  @{ File = "snippets/scripts.liquid"; Pattern = 'routes:\s*\{[\s\S]*?cart_add_url:'; Desc = "Theme.routes cart_add_url" },
  @{ File = "snippets/cart-products.liquid"; Pattern = 'id=[\x27\x22]cart-form[\x27\x22]'; Desc = "cart-form id" },
  @{ File = "snippets/cart-summary.liquid"; Pattern = 'name=[\x27\x22]checkout[\x27\x22]'; Desc = "checkout submit button" },
  @{ File = "snippets/cart-summary.liquid"; Pattern = '\{\{\s*content_for_additional_checkout_buttons\s*\}\}'; Desc = "additional checkout buttons" },
  @{ File = "snippets/add-to-cart-button.liquid"; Pattern = 'name=[\x27\x22]add[\x27\x22]'; Desc = "add-to-cart button" },
  @{ File = "blocks/accelerated-checkout.liquid"; Pattern = '\|\s*payment_button'; Desc = "payment_button filter" }
)

$missingHookCount = 0
foreach ($h in $hooksToCheck) {
  $p = Join-Path $ProjectRoot $h.File
  if (-not (Test-Path $p)) {
    $missingHookCount++
    continue
  }
  $c = Get-Content -LiteralPath $p -Raw
  if (-not [regex]::IsMatch($c, $h.Pattern)) {
    $missingHookCount++
  }
}
Assert-Check "All 14 Shopify platform hooks independently verified present in theme" ($missingHookCount -eq 0) "$missingHookCount hook(s) missing"

# ------------------------------------------------------------------------------
# 5. Suite 4 Falsifiability: Design Tokens & WCAG Contrast Precision
# ------------------------------------------------------------------------------
Write-Host "`n--- 5. Suite 4 Falsifiability: Tokens & WCAG Contrast Precision ---" -ForegroundColor Yellow

# WCAG helper
if (-not ([System.Management.Automation.PSTypeName]'HeravynWcagAudit').Type) {
  Add-Type -TypeDefinition @"
public static class HeravynWcagAudit {
    public static double RelativeLuminance(string hex) {
        hex = hex.Trim().TrimStart('#');
        double r = System.Convert.ToInt32(hex.Substring(0, 2), 16) / 255.0;
        double g = System.Convert.ToInt32(hex.Substring(2, 2), 16) / 255.0;
        double b = System.Convert.ToInt32(hex.Substring(4, 2), 16) / 255.0;
        double rL = (r <= 0.03928) ? (r / 12.92) : System.Math.Pow((r + 0.055) / 1.055, 2.4);
        double gL = (g <= 0.03928) ? (g / 12.92) : System.Math.Pow((g + 0.055) / 1.055, 2.4);
        double bL = (b <= 0.03928) ? (b / 12.92) : System.Math.Pow((b + 0.055) / 1.055, 2.4);
        return 0.2126 * rL + 0.7152 * gL + 0.0722 * bL;
    }
    public static double ContrastRatio(string hex1, string hex2) {
        double l1 = RelativeLuminance(hex1);
        double l2 = RelativeLuminance(hex2);
        double lighter = System.Math.Max(l1, l2);
        double darker = System.Math.Min(l1, l2);
        return System.Math.Round((lighter + 0.05) / (darker + 0.05), 2);
    }
}
"@
}

# Boundary Condition Tests
$blackWhiteContrast = [HeravynWcagAudit]::ContrastRatio("#000000", "#FFFFFF")
Assert-Check "WCAG contrast boundary: Pure Black vs Pure White equals 21:1" ($blackWhiteContrast -eq 21.0) "Expected 21, got $blackWhiteContrast"

$sameColorContrast = [HeravynWcagAudit]::ContrastRatio("#FAF7F3", "#FAF7F3")
Assert-Check "WCAG contrast boundary: Identical colors equals 1:1" ($sameColorContrast -eq 1.0) "Expected 1, got $sameColorContrast"

# Negative Test 4.3: Low contrast detection (e.g., #E9DED5 on #FAF7F3 is ~1.25:1, must fail normal text AA)
$lowContrast = [HeravynWcagAudit]::ContrastRatio("#E9DED5", "#FAF7F3")
Assert-Check "Suite 4 detects inaccessible color combinations (Soft Beige on Warm Ivory = $($lowContrast):1 < 4.5:1)" ($lowContrast -lt 4.5) "Low contrast not detected"

# Verify actual theme settings_data.json tokens
$sdRaw = Get-Content -LiteralPath (Join-Path $ProjectRoot "config/settings_data.json") -Raw
$sdClean = [regex]::Replace($sdRaw, '^\s*/\*[\s\S]*?\*/\s*', '')
$sdObj = ConvertFrom-Json $sdClean

$expectedTokens = @{
  "background" = "#FAF7F3"
  "foreground" = "#252525"
  "color1"     = "#B87570"
  "color2"     = "#E9DED5"
  "color3"     = "#FFFFFF"
}

$tokenMismatch = 0
foreach ($k in $expectedTokens.Keys) {
  if ($sdObj.current.color_palette.$k -ne $expectedTokens[$k]) { $tokenMismatch++ }
  if ($sdObj.presets.Default.color_palette.$k -ne $expectedTokens[$k]) { $tokenMismatch++ }
}
Assert-Check "All 5 HERAVYN tokens match exactly in current & presets" ($tokenMismatch -eq 0) "Token mismatch found"
Assert-Check "Primary button border radius equals 14" ($sdObj.current.button_border_radius_primary -eq 14) "Button radius is not 14"
Assert-Check "Quick-add drawer is enabled" ($sdObj.current.quick_add -eq $true) "Quick-add disabled"

# ------------------------------------------------------------------------------
# 6. Suite 5 Falsifiability: Git Immutability & Scope Containment
# ------------------------------------------------------------------------------
Write-Host "`n--- 6. Suite 5 Falsifiability: Git Immutability & Scope ---" -ForegroundColor Yellow

$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$gitDiffOutput = & git -c core.safecrlf=false -C $ProjectRoot diff --name-only 2>$null
$gitDiffStaged = & git -c core.safecrlf=false -C $ProjectRoot diff --staged --name-only 2>$null
$schemaDiff    = & git -c core.safecrlf=false -C $ProjectRoot diff config/settings_schema.json 2>$null
$paletteDiff   = & git -c core.safecrlf=false -C $ProjectRoot diff snippets/color-palette.liquid 2>$null
$ErrorActionPreference = $prevEAP

$allModified = @($gitDiffOutput) + @($gitDiffStaged) | Where-Object { $_ -ne $null -and $_.Trim() -ne "" } | Select-Object -Unique
$themeModified = $allModified | Where-Object {
  $_ -notmatch '^\.agents[\\/]' -and
  $_ -notmatch '^tests[\\/]' -and
  $_ -notmatch '\.md$'
} | ForEach-Object { $_.Replace('\', '/') }

$expectedThemeFiles = @(
  "config/settings_data.json",
  "sections/footer-group.json",
  "sections/header-group.json",
  "templates/index.json"
)

$unexpectedFiles = $themeModified | Where-Object { $expectedThemeFiles -notcontains $_ }
$missingExpected = $expectedThemeFiles | Where-Object { $themeModified -notcontains $_ }

Assert-Check "Strict Git Immutability: ONLY the 4 intended theme files modified" ($unexpectedFiles.Count -eq 0 -and $themeModified.Count -eq 4) "Unexpected files: $($unexpectedFiles -join ', ')"
Assert-Check "Zero .liquid files modified in git" (@($allModified | Where-Object { $_ -match '\.liquid$' }).Count -eq 0) "Liquid files were modified!"
Assert-Check "config/settings_schema.json has zero diff" (@($schemaDiff).Count -eq 0) "settings_schema.json has diff!"
Assert-Check "snippets/color-palette.liquid has zero diff" (@($paletteDiff).Count -eq 0) "color-palette.liquid has diff!"

# ------------------------------------------------------------------------------
# 7. Summary & Verdict
# ------------------------------------------------------------------------------
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "                ADVERSARIAL CHALLENGE EXECUTION SUMMARY                         " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Checks Executed : $totalChecks"
Write-Host "  Checks Passed   : $passedChecks" -ForegroundColor Green
Write-Host "  Checks Failed   : $failedChecks" -ForegroundColor $(if ($failedChecks -eq 0) { "Green" } else { "Red" })

if ($failedChecks -gt 0) {
  Write-Host "`nADVERSARIAL AUDIT FAILED with $failedChecks issue(s):" -ForegroundColor Red
  foreach ($iss in $criticalIssues) {
    Write-Host "  $iss" -ForegroundColor Red
  }
  exit 1
} else {
  Write-Host "`nADVERSARIAL AUDIT PASSED: All verification suites, invariants, and falsifiability tests verified." -ForegroundColor Green
  exit 0
}
