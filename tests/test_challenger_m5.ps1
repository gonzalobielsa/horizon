# tests/test_challenger_m5.ps1
# Independent Adversarial Verification Harness for Milestone 5
# Author: challenger_m5_2

$ErrorActionPreference = "Stop"

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "       CHALLENGER M5-2: INDEPENDENT EMPIRICAL VERIFICATION HARNESS      " -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan

# 1. Exact WCAG 2.1 Luminance and Contrast Calculation
function Get-RelativeLuminance([string]$hex) {
    $clean = $hex.TrimStart('#')
    $r8 = [Convert]::ToInt32($clean.Substring(0, 2), 16) / 255.0
    $g8 = [Convert]::ToInt32($clean.Substring(2, 2), 16) / 255.0
    $b8 = [Convert]::ToInt32($clean.Substring(4, 2), 16) / 255.0

    $toLinear = {
        param([double]$c)
        if ($c -le 0.03928) {
            return $c / 12.92
        } else {
            return [Math]::Pow(($c + 0.055) / 1.055, 2.4)
        }
    }

    $rLin = & $toLinear $r8
    $gLin = & $toLinear $g8
    $bLin = & $toLinear $b8

    return (0.2126 * $rLin) + (0.7152 * $gLin) + (0.0722 * $bLin)
}

function Get-ContrastRatio([string]$hex1, [string]$hex2) {
    $l1 = Get-RelativeLuminance $hex1
    $l2 = Get-RelativeLuminance $hex2
    $lighter = [Math]::Max($l1, $l2)
    $darker = [Math]::Min($l1, $l2)
    return ($lighter + 0.05) / ($darker + 0.05)
}

$tokens = [ordered]@{
    "Warm Ivory"    = "#FAF7F3"
    "Deep Charcoal" = "#252525"
    "Soft Beige"    = "#E9DED5"
    "Dusty Rose"    = "#B87570"
    "White"         = "#FFFFFF"
}

Write-Host "`n--- SECTION 1: RELATIVE LUMINANCES (WCAG 2.1 sRGB) ---" -ForegroundColor Yellow
$luminances = @{}
foreach ($token in $tokens.GetEnumerator()) {
    $lum = Get-RelativeLuminance $token.Value
    $luminances[$token.Key] = $lum
    Write-Host ("  {0,-15} ({1}): L = {2:F6}" -f $token.Key, $token.Value, $lum)
}

Write-Host "`n--- SECTION 2: REQUIRED PAIRWISE CONTRAST RATIOS ---" -ForegroundColor Yellow
$pairs = @(
    [PSCustomObject]@{
        Foreground = "Deep Charcoal"; Bg = "Warm Ivory"
        FgHex = "#252525"; BgHex = "#FAF7F3"
        ReqAA = 4.5; ReqAAA = 7.0; Usage = "Primary Body Text on Canvas"
    },
    [PSCustomObject]@{
        Foreground = "Deep Charcoal"; Bg = "Soft Beige"
        FgHex = "#252525"; BgHex = "#E9DED5"
        ReqAA = 4.5; ReqAAA = 7.0; Usage = "Card and Secondary Container Text"
    },
    [PSCustomObject]@{
        Foreground = "White"; Bg = "Dusty Rose"
        FgHex = "#FFFFFF"; BgHex = "#B87570"
        ReqAA = 3.0; ReqAAA = 4.5; Usage = "Primary Accent / Button Text (Bold >= 14pt / UI)"
    },
    [PSCustomObject]@{
        Foreground = "Deep Charcoal"; Bg = "White"
        FgHex = "#252525"; BgHex = "#FFFFFF"
        ReqAA = 4.5; ReqAAA = 7.0; Usage = "Input Fields, Search & Popovers Text"
    },
    [PSCustomObject]@{
        Foreground = "Dusty Rose"; Bg = "Warm Ivory"
        FgHex = "#B87570"; BgHex = "#FAF7F3"
        ReqAA = 3.0; ReqAAA = 4.5; Usage = "Interactive Accent / UI Icons & Borders on Canvas"
    }
)

$allContrastPassed = $true
foreach ($p in $pairs) {
    $ratio = Get-ContrastRatio $p.FgHex $p.BgHex
    $passAA = $ratio -ge $p.ReqAA
    $passAAA = $ratio -ge $p.ReqAAA
    
    $status = if ($passAA) { "PASS" } else { "FAIL" }
    $color = if ($passAA) { "Green" } else { "Red" }
    if (-not $passAA) { $allContrastPassed = $false }

    Write-Host ("  [{0}] {1} on {2} ({3} / {4})" -f $status, $p.Foreground, $p.Bg, $p.FgHex, $p.BgHex) -ForegroundColor $color
    Write-Host ("        Contrast Ratio: {0:F4}:1" -f $ratio)
    Write-Host ("        Requirement   : >= {0:F1}:1 (AA) [{1}] | >= {2:F1}:1 (AAA) [{3}]" -f $p.ReqAA, $(if($passAA){"MET"}else{"UNMET"}), $p.ReqAAA, $(if($passAAA){"MET"}else{"UNMET"}))
    Write-Host ("        Context       : {0}" -f $p.Usage)
}

# 3. Theme Editor Live Customization & Git Immutability Verification
Write-Host "`n--- SECTION 3: THEME EDITOR LIVE CUSTOMIZATION INTEGRITY ---" -ForegroundColor Yellow

$schemaDiff = git diff --name-only config/settings_schema.json
$paletteDiff = git diff --name-only snippets/color-palette.liquid

if ([string]::IsNullOrWhiteSpace($schemaDiff)) {
    Write-Host "  [PASS] config/settings_schema.json has 0 git diff (Shopify Theme Editor controls preserved)." -ForegroundColor Green
} else {
    Write-Host "  [FAIL] config/settings_schema.json modified unexpectedly!" -ForegroundColor Red
}

if ([string]::IsNullOrWhiteSpace($paletteDiff)) {
    Write-Host "  [PASS] snippets/color-palette.liquid has 0 git diff (CSS custom properties engine preserved)." -ForegroundColor Green
} else {
    Write-Host "  [FAIL] snippets/color-palette.liquid modified unexpectedly!" -ForegroundColor Red
}

$allModified = git diff --name-only | Where-Object { $_.Trim() -ne "" }
Write-Host ("  Total modified tracked theme files: {0}" -f $allModified.Count)
$expectedModified = @(
    "config/settings_data.json",
    "sections/footer-group.json",
    "sections/header-group.json",
    "templates/index.json"
)

$unexpectedModified = $allModified | Where-Object { $expectedModified -notcontains $_ }
if ($unexpectedModified.Count -eq 0) {
    Write-Host "  [PASS] Modified files strictly bounded to exactly the 4 customized theme files." -ForegroundColor Green
} else {
    Write-Host ("  [FAIL] Unexpected files modified: {0}" -f ($unexpectedModified -join ", ")) -ForegroundColor Red
}

# 4. Color Palette and Schemes in settings_data.json
Write-Host "`n--- SECTION 4: COLOR SCHEMES CONFIGURATION AUDIT ---" -ForegroundColor Yellow
$rawSettings = Get-Content "c:\Users\Reinis Kurms\Desktop\reinis\config\settings_data.json" -Raw
$cleanSettings = $rawSettings -replace '(?s)/\*.*?\*/', ''
$settingsData = $cleanSettings | ConvertFrom-Json
$palette = $settingsData.current.color_palette
Write-Host ("  background: {0}" -f $palette.background)
Write-Host ("  foreground: {0}" -f $palette.foreground)
Write-Host ("  color1    : {0}" -f $palette.color1)
Write-Host ("  color2    : {0}" -f $palette.color2)
Write-Host ("  color3    : {0}" -f $palette.color3)

$schemes = $settingsData.current.color_schemes
Write-Host ("  Detected {0} color schemes defined in current settings." -f $schemes.PSObject.Properties.Count)
foreach ($prop in $schemes.PSObject.Properties) {
    $s = $prop.Value
    Write-Host ("  Scheme [{0}]: bg={1}, text={2}, p-btn-bg={3}, p-btn-txt={4}, s-btn-bg={5}, s-btn-txt={6}" -f `
        $prop.Name, $s.settings.background, $s.settings.text, $s.settings.primary_button_background, `
        $s.settings.primary_button_text, $s.settings.secondary_button_background, $s.settings.secondary_button_text)
}

# 5. Native Shopify Structural Hook Check
Write-Host "`n--- SECTION 5: CRITICAL NATIVE SHOPIFY HOOKS AUDIT ---" -ForegroundColor Yellow
$themeLiquid = Get-Content "c:\Users\Reinis Kurms\Desktop\reinis\layout\theme.liquid" -Raw
$hooks = @(
    "content_for_header",
    "content_for_layout",
    "sections 'header-group'",
    "sections 'footer-group'",
    "render 'cart-drawer'",
    "render 'search-modal'"
)

foreach ($hook in $hooks) {
    if ($themeLiquid -match [regex]::Escape($hook)) {
        Write-Host ("  [PASS] layout/theme.liquid contains: '{0}'" -f $hook) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] layout/theme.liquid MISSING: '{0}'" -f $hook) -ForegroundColor Red
    }
}

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "                CHALLENGER M5-2 VERIFICATION COMPLETE                   " -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
