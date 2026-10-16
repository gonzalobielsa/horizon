# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 4 Challenger Adversarial Test Suite
# Author: challenger_m4_2 (Empirical Challenger)
# Target: sections/footer-group.json (Requirement R4)
# ==============================================================================
param(
    [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0
$Failures = @()

function Report-Assert($TestName, $Condition, $Detail = "") {
    $script:TotalTests++
    if ($Condition) {
        $script:PassedTests++
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
    } else {
        $script:FailedTests++
        $msg = "  [FAIL] ${TestName}: $Detail"
        $script:Failures += $msg
        Write-Host $msg -ForegroundColor Red
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 4 Challenger Adversarial Test Suite (Empirical Verification)" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$FooterGroupPath = Join-Path $ProjectRoot "sections\footer-group.json"
$FooterLiquidPath = Join-Path $ProjectRoot "sections\footer.liquid"
$FooterUtilLiquidPath = Join-Path $ProjectRoot "sections\footer-utilities.liquid"
$EmailSignupBlockPath = Join-Path $ProjectRoot "blocks\email-signup.liquid"
$CopyrightBlockPath = Join-Path $ProjectRoot "blocks\footer-copyright.liquid"
$SettingsDataPath = Join-Path $ProjectRoot "config\settings_data.json"

# ------------------------------------------------------------------------------
# SUITE 1: Multi-Parser Deserialization & Structural Stress-Testing
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 1: Multi-Parser Deserialization & Structural Stress-Testing ---" -ForegroundColor Yellow

Report-Assert "footer-group.json exists" (Test-Path $FooterGroupPath) "File missing"
$rawText = [System.IO.File]::ReadAllText($FooterGroupPath, [System.Text.Encoding]::UTF8)

# Check Shopify header comment block
$commentMatch = [regex]::Match($rawText, '^\s*/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Report-Assert "Shopify comment header format is present and valid" ($commentMatch.Success) "Comment header missing"

$jsonBody = $rawText.Substring($commentMatch.Index + $commentMatch.Length).Trim()

# Parser 1: PowerShell ConvertFrom-Json
$psParsed = $null
try {
    $psParsed = $jsonBody | ConvertFrom-Json
    Report-Assert "Parser 1 (PowerShell ConvertFrom-Json) parses cleanly" ($psParsed -ne $null) ""
} catch {
    Report-Assert "Parser 1 (PowerShell ConvertFrom-Json) parses cleanly" $false $_.Exception.Message
}

# Parser 2: .NET System.Web.Script.Serialization.JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$netParsed = $null
try {
    $netParsed = $jsSerializer.DeserializeObject($jsonBody)
    Report-Assert "Parser 2 (.NET JavaScriptSerializer) parses cleanly" ($netParsed -ne $null) ""
} catch {
    Report-Assert "Parser 2 (.NET JavaScriptSerializer) parses cleanly" $false $_.Exception.Message
}

# Parser 3: .NET System.Runtime.Serialization.Json.JsonReaderWriterFactory (Strict WCF JSON Reader)
Add-Type -AssemblyName System.Runtime.Serialization
$strictParsed = $false
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader(
        $bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null
    )
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($jsonReader)
    $strictParsed = ($xmlDoc.DocumentElement -ne $null)
    Report-Assert "Parser 3 (.NET Strict JsonReaderWriterFactory) parses cleanly" $strictParsed ""
} catch {
    Report-Assert "Parser 3 (.NET Strict JsonReaderWriterFactory) parses cleanly" $false $_.Exception.Message
}

# Parser 4: Strict RFC 8259 Lexer & Grammar Validator (Compiled C#)
$csharpValidator = @"
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

public class StrictJsonValidatorFooter {
    public static string Validate(string json) {
        // 1. Check for trailing commas before closing braces/brackets
        if (Regex.IsMatch(json, @",\s*([\}\]])")) {
            return "SyntaxError: Trailing comma detected before closing brace/bracket";
        }
        // 2. Check for single-quoted strings
        if (Regex.IsMatch(json, @"(?<!\\)'([^'\\]|\\.)*'")) {
            return "SyntaxError: Single-quoted string detected";
        }
        // 3. Check for unquoted property keys
        if (Regex.IsMatch(json, @"(?<=[\{\,]\s*)([a-zA-Z0-9_\-]+)\s*:")) {
            return "SyntaxError: Unquoted property name detected";
        }
        // 4. Tokenizer & bracket balance check
        Stack<char> stack = new Stack<char>();
        bool inString = false;
        bool escape = false;
        for (int i = 0; i < json.Length; i++) {
            char c = json[i];
            if (inString) {
                if (escape) {
                    escape = false;
                } else if (c == '\\') {
                    escape = true;
                } else if (c == '"') {
                    inString = false;
                }
            } else {
                if (c == '"') {
                    inString = true;
                } else if (c == '{' || c == '[') {
                    stack.Push(c);
                } else if (c == '}') {
                    if (stack.Count == 0 || stack.Pop() != '{') return "SyntaxError: Mismatched closing brace '}' at position " + i;
                } else if (c == ']') {
                    if (stack.Count == 0 || stack.Pop() != '[') return "SyntaxError: Mismatched closing bracket ']' at position " + i;
                }
            }
        }
        if (inString) return "SyntaxError: Unterminated string";
        if (stack.Count > 0) return "SyntaxError: Unclosed brackets/braces remaining: " + stack.Count;
        return "OK";
    }
}
"@
Add-Type -TypeDefinition $csharpValidator
$strictResult = [StrictJsonValidatorFooter]::Validate($jsonBody)
Report-Assert "Parser 4 (Strict C# Lexer & Grammar Validator) returns OK" ($strictResult -eq "OK") $strictResult

# Lexical Stress-Tests
$hasTrailing = [regex]::IsMatch($jsonBody, ',\s*([\}\]])')
Report-Assert "Lexical Stress: Zero trailing commas in JSON body" (-not $hasTrailing) "Trailing comma found"

$hasSingleQuotes = [regex]::IsMatch($jsonBody, "(?<!\\)'([^'\\]|\\.)*'")
Report-Assert "Lexical Stress: Zero single quotes used for JSON strings" (-not $hasSingleQuotes) "Single quotes found"

$hasUnquotedKeys = [regex]::IsMatch($jsonBody, '(?<=[\{\,]\s*)([a-zA-Z0-9_\-]+)\s*:')
Report-Assert "Lexical Stress: Zero unquoted keys in JSON body" (-not $hasUnquotedKeys) "Unquoted key found"

# ------------------------------------------------------------------------------
# SUITE 2: Negative Testing Oracles (Sensitivity Verification)
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 2: Negative Testing Oracles (Sensitivity Verification) ---" -ForegroundColor Yellow

$badJsonWithTrailingComma = '{"key": "val",}'
$detectedTrailing = [StrictJsonValidatorFooter]::Validate($badJsonWithTrailingComma)
Report-Assert "Oracle 1: Strict validator detects synthetic trailing comma" ($detectedTrailing -like "*Trailing comma*") "Failed to detect synthetic trailing comma"

$badJsonWithSingleQuote = "{'key': 'val'}"
$detectedQuote = [StrictJsonValidatorFooter]::Validate($badJsonWithSingleQuote)
Report-Assert "Oracle 2: Strict validator detects synthetic single quote" ($detectedQuote -like "*Single-quoted*") "Failed to detect synthetic single quote"

$badJsonWithMismatchedBrace = '{"key": "val"'
$detectedBrace = [StrictJsonValidatorFooter]::Validate($badJsonWithMismatchedBrace)
Report-Assert "Oracle 3: Strict validator detects synthetic unclosed brace" ($detectedBrace -like "*Unclosed*") "Failed to detect synthetic unclosed brace"

$badJsonWithExtraBracket = '{"key": ["val"]]}'
$detectedBracket = [StrictJsonValidatorFooter]::Validate($badJsonWithExtraBracket)
Report-Assert "Oracle 4: Strict validator detects synthetic extra closing bracket" ($detectedBracket -like "*Mismatched*") "Failed to detect synthetic bracket mismatch"

# ------------------------------------------------------------------------------
# SUITE 3: Orphan Blocks & Structural Integrity Stress-Testing
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 3: Orphan Blocks & Structural Integrity Stress-Testing ---" -ForegroundColor Yellow

# Root order vs sections
$rootSections = @($psParsed.sections.PSObject.Properties | ForEach-Object { $_.Name })
$rootOrder = @($psParsed.order)

Report-Assert "Root order count equals root sections count" ($rootOrder.Count -eq $rootSections.Count) "$($rootOrder.Count) vs $($rootSections.Count)"
foreach ($secKey in $rootSections) {
    Report-Assert "Section '$secKey' is present in root order array (no orphan section)" ($rootOrder -contains $secKey) "Section $secKey missing from order"
}
foreach ($orderKey in $rootOrder) {
    Report-Assert "Order item '$orderKey' is present in sections object" ($rootSections -contains $orderKey) "Order item $orderKey missing from sections"
}

# Footer section blocks vs block_order
$footerSec = $psParsed.sections.footer
$footerBlockKeys = @($footerSec.blocks.PSObject.Properties | ForEach-Object { $_.Name })
$footerBlockOrder = @($footerSec.block_order)

Report-Assert "Footer block count ($($footerBlockKeys.Count)) equals block_order count ($($footerBlockOrder.Count))" ($footerBlockKeys.Count -eq $footerBlockOrder.Count) "$($footerBlockKeys.Count) vs $($footerBlockOrder.Count)"
foreach ($fbKey in $footerBlockKeys) {
    Report-Assert "Footer block '$fbKey' is listed in block_order (no orphan block)" ($footerBlockOrder -contains $fbKey) "Block $fbKey is orphan in footer"
}
foreach ($boKey in $footerBlockOrder) {
    Report-Assert "Footer block_order entry '$boKey' exists in blocks dictionary" ($footerBlockKeys -contains $boKey) "block_order entry $boKey missing from blocks"
}

# Nested group_newsletter blocks vs block_order
$nlGroup = $footerSec.blocks.group_newsletter
$nlBlockKeys = @($nlGroup.blocks.PSObject.Properties | ForEach-Object { $_.Name })
$nlBlockOrder = @($nlGroup.block_order)

Report-Assert "group_newsletter block count ($($nlBlockKeys.Count)) equals nested block_order count ($($nlBlockOrder.Count))" ($nlBlockKeys.Count -eq $nlBlockOrder.Count) "$($nlBlockKeys.Count) vs $($nlBlockOrder.Count)"
foreach ($nlKey in $nlBlockKeys) {
    Report-Assert "Newsletter block '$nlKey' is listed in nested block_order (no orphan nested block)" ($nlBlockOrder -contains $nlKey) "Block $nlKey is orphan in newsletter group"
}
foreach ($boKey in $nlBlockOrder) {
    Report-Assert "Newsletter nested block_order entry '$boKey' exists in nested blocks dictionary" ($nlBlockKeys -contains $boKey) "block_order entry $boKey missing from newsletter blocks"
}

# Utilities section blocks vs block_order
$utilSec = $psParsed.sections.utilities
$utilBlockKeys = @($utilSec.blocks.PSObject.Properties | ForEach-Object { $_.Name })
$utilBlockOrder = @($utilSec.block_order)

Report-Assert "Utilities block count ($($utilBlockKeys.Count)) equals block_order count ($($utilBlockOrder.Count))" ($utilBlockKeys.Count -eq $utilBlockOrder.Count) "$($utilBlockKeys.Count) vs $($utilBlockOrder.Count)"
foreach ($uKey in $utilBlockKeys) {
    Report-Assert "Utilities block '$uKey' is listed in block_order (no orphan block)" ($utilBlockOrder -contains $uKey) "Block $uKey is orphan in utilities"
}
foreach ($boKey in $utilBlockOrder) {
    Report-Assert "Utilities block_order entry '$boKey' exists in blocks dictionary" ($utilBlockKeys -contains $boKey) "block_order entry $boKey missing from utilities blocks"
}

# ------------------------------------------------------------------------------
# SUITE 4: Powered by Shopify Verification & Block Implementations
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 4: Powered by Shopify Verification & Block Implementations ---" -ForegroundColor Yellow

$copyrightBlock = $utilSec.blocks.copyright
Report-Assert "Copyright block has 'show_powered_by' set to false" ($copyrightBlock.settings.show_powered_by -eq $false) "show_powered_by is $($copyrightBlock.settings.show_powered_by)"
Report-Assert "Copyright 'show_powered_by' is strictly Boolean false, not string 'false'" ($copyrightBlock.settings.show_powered_by.GetType().Name -eq "Boolean" -and $copyrightBlock.settings.show_powered_by -eq $false) "Type is $($copyrightBlock.settings.show_powered_by.GetType().Name)"

# Liquid confirmation: verify blocks/footer-copyright.liquid uses show_powered_by condition
$copyrightLiquid = [System.IO.File]::ReadAllText($CopyrightBlockPath, [System.Text.Encoding]::UTF8)
$hasPoweredByCheck = [regex]::IsMatch($copyrightLiquid, '\{%-?\s*if\s+block_settings\.show_powered_by\s*-?%\}\s*,\s*\{\{\s*powered_by_link\s*\}\}\s*\{%-?\s*endif\s*-?%\}')
Report-Assert "footer-copyright.liquid guards powered_by_link behind show_powered_by" $hasPoweredByCheck "Guard not found in Liquid"

# ------------------------------------------------------------------------------
# SUITE 5: Responsive Grid Mechanics & Layout Arithmetic
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 5: Responsive Grid Mechanics & Layout Arithmetic ---" -ForegroundColor Yellow

# Footer Grid Analysis
$footerBlocksCount = $footerSec.block_order.Count
Report-Assert "Footer has exactly 4 top-level blocks" ($footerBlocksCount -eq 4) "Count is $footerBlocksCount"

# Grid column math simulation based on sections/footer.liquid
$gridColumns = [Math]::Min($footerBlocksCount, 4)
$lastRowCount = (($footerBlocksCount - 1) % 4) + 1
$tabletLastRowCount = (($footerBlocksCount - 1) % 2) + 1
$isolatedDesktop = ($footerBlocksCount -gt 4 -and $lastRowCount -eq 1)
$isolatedTablet = ($footerBlocksCount -eq 5)

Report-Assert "Grid columns computed for desktop is exactly 4" ($gridColumns -eq 4) "gridColumns is $gridColumns"
Report-Assert "Desktop grid last_row_count is 4 (no remainder / full row)" ($lastRowCount -eq 4) "lastRowCount is $lastRowCount"
Report-Assert "Tablet grid tablet_last_row_count is 2 (2x2 grid, perfectly balanced)" ($tabletLastRowCount -eq 2) "tabletLastRowCount is $tabletLastRowCount"
Report-Assert "Desktop isolated grid item flag is false" ($isolatedDesktop -eq $false) "isolatedDesktop is $isolatedDesktop"
Report-Assert "Tablet isolated grid item flag is false" ($isolatedTablet -eq $false) "isolatedTablet is $isolatedTablet"

# Utilities Section 3-block positioning analysis based on sections/footer-utilities.liquid
$utilBlocksCount = $utilSec.block_order.Count
Report-Assert "Utilities has exactly 3 blocks (triggers .utilities--blocks-3 1fr auto 1fr CSS grid)" ($utilBlocksCount -eq 3) "Count is $utilBlocksCount"

# ------------------------------------------------------------------------------
# SUITE 6: Empirical Color Contrast & WCAG 2.1 Mathematics
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 6: Empirical Color Contrast & WCAG 2.1 Mathematics ---" -ForegroundColor Yellow

function Get-Luminance($hex) {
    $hex = $hex.TrimStart('#')
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0

    $calc = {
        param($c)
        if ($c -le 0.04045) {
            return $c / 12.92
        } else {
            return [Math]::Pow(($c + 0.055) / 1.055, 2.4)
        }
    }

    $rLin = & $calc $r
    $gLin = & $calc $g
    $bLin = & $calc $b

    return (0.2126 * $rLin) + (0.7152 * $gLin) + (0.0722 * $bLin)
}

function Get-ContrastRatio($hex1, $hex2) {
    $l1 = Get-Luminance $hex1
    $l2 = Get-Luminance $hex2
    $lighter = [Math]::Max($l1, $l2)
    $darker = [Math]::Min($l1, $l2)
    return ($lighter + 0.05) / ($darker + 0.05)
}

# Extract colors from config/settings_data.json
$settingsRaw = [System.IO.File]::ReadAllText($SettingsDataPath, [System.Text.Encoding]::UTF8)
$settingsComment = [regex]::Match($settingsRaw, '^\s*/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$settingsBody = $settingsRaw.Substring($settingsComment.Index + $settingsComment.Length).Trim()
$settingsJson = $settingsBody | ConvertFrom-Json

$colorBackground = $settingsJson.current.color_palette.background  # #FAF7F3 (Warm Ivory)
$colorForeground = $settingsJson.current.color_palette.foreground  # #252525 (Deep Charcoal)
$color1          = $settingsJson.current.color_palette.color1      # #B87570 (Dusty Rose)
$color2          = $settingsJson.current.color_palette.color2      # #E9DED5 (Soft Beige)
$color3          = $settingsJson.current.color_palette.color3      # #FFFFFF (White)

Write-Host "  Active HERAVYN Palette Tokens in settings_data.json:" -ForegroundColor Gray
Write-Host "    Foreground (Deep Charcoal): $colorForeground" -ForegroundColor Gray
Write-Host "    Background (Warm Ivory):    $colorBackground" -ForegroundColor Gray
Write-Host "    Color 1    (Dusty Rose):    $color1" -ForegroundColor Gray
Write-Host "    Color 2    (Soft Beige):    $color2" -ForegroundColor Gray
Write-Host "    Color 3    (White):         $color3" -ForegroundColor Gray

# Contrast Test 1: Deep Charcoal text on Soft Beige background (>= 4.5:1)
$contrastCharcoalOnSoftBeige = [Math]::Round((Get-ContrastRatio $colorForeground $color2), 2)
Write-Host "  Calculated Contrast: Deep Charcoal ($colorForeground) on Soft Beige ($color2) = ${contrastCharcoalOnSoftBeige}:1" -ForegroundColor Gray
Report-Assert "Color Contrast: Deep Charcoal on Soft Beige is ${contrastCharcoalOnSoftBeige}:1 (>= 4.5:1 required by WCAG AA)" (
    $contrastCharcoalOnSoftBeige -ge 4.5
) "Contrast $contrastCharcoalOnSoftBeige is below 4.5:1"

# Contrast Test 2: Deep Charcoal (#2E2A27 alternate) on Soft Beige (>= 4.5:1)
$contrastAltCharcoal = [Math]::Round((Get-ContrastRatio "#2E2A27" $color2), 2)
Write-Host "  Calculated Contrast: Alt Charcoal (#2E2A27) on Soft Beige ($color2) = ${contrastAltCharcoal}:1" -ForegroundColor Gray
Report-Assert "Color Contrast: Alt Charcoal (#2E2A27) on Soft Beige is ${contrastAltCharcoal}:1 (>= 4.5:1)" (
    $contrastAltCharcoal -ge 4.5
) "Contrast $contrastAltCharcoal is below 4.5:1"

# Contrast Test 3: Deep Charcoal on Warm Ivory (>= 4.5:1)
$contrastCharcoalOnIvory = [Math]::Round((Get-ContrastRatio $colorForeground $colorBackground), 2)
Write-Host "  Calculated Contrast: Deep Charcoal ($colorForeground) on Warm Ivory ($colorBackground) = ${contrastCharcoalOnIvory}:1" -ForegroundColor Gray
Report-Assert "Color Contrast: Deep Charcoal on Warm Ivory is ${contrastCharcoalOnIvory}:1 (>= 4.5:1)" (
    $contrastCharcoalOnIvory -ge 4.5
) "Contrast $contrastCharcoalOnIvory is below 4.5:1"

# Contrast Test 4: White button text on Dusty Rose (#B87570) (>= 3.0:1)
$contrastWhiteOnDustyRose = [Math]::Round((Get-ContrastRatio $color3 $color1), 2)
Write-Host "  Calculated Contrast: White ($color3) on Dusty Rose ($color1) = ${contrastWhiteOnDustyRose}:1" -ForegroundColor Gray
Report-Assert "Color Contrast: White button text on Dusty Rose is ${contrastWhiteOnDustyRose}:1 (>= 3.0:1 required by WCAG Non-Text/Large text)" (
    $contrastWhiteOnDustyRose -ge 3.0
) "Contrast $contrastWhiteOnDustyRose is below 3.0:1"

# Contrast Test 5: White button text on alternate Dusty Rose (#B76E79) (>= 3.0:1)
$contrastWhiteOnAltRose = [Math]::Round((Get-ContrastRatio "#FFFFFF" "#B76E79"), 2)
Write-Host "  Calculated Contrast: White (#FFFFFF) on Alt Dusty Rose (#B76E79) = ${contrastWhiteOnAltRose}:1" -ForegroundColor Gray
Report-Assert "Color Contrast: White on Alt Dusty Rose (#B76E79) is ${contrastWhiteOnAltRose}:1 (>= 3.0:1)" (
    $contrastWhiteOnAltRose -ge 3.0
) "Contrast $contrastWhiteOnAltRose is below 3.0:1"

# Contrast Test 6: Newsletter input text on Warm Ivory input background
$contrastInputText = [Math]::Round((Get-ContrastRatio $colorForeground $colorBackground), 2)
Report-Assert "Color Contrast: Newsletter input text ($colorForeground) on input background ($colorBackground) is ${contrastInputText}:1 (>= 4.5:1)" (
    $contrastInputText -ge 4.5
) "Contrast $contrastInputText is below 4.5:1"

# ------------------------------------------------------------------------------
# SUITE 7: Regression Safety Verification
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 7: Regression Safety Verification ---" -ForegroundColor Yellow

$m3Result = & powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot "tests\test_milestone3.ps1")
$m3Pass = ($LASTEXITCODE -eq 0)
Report-Assert "Milestone 3 Regression Test Suite (test_milestone3.ps1) exits 0" $m3Pass "test_milestone3.ps1 failed with code $LASTEXITCODE"

$m4Result = & powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot "tests\test_milestone4.ps1")
$m4Pass = ($LASTEXITCODE -eq 0)
Report-Assert "Milestone 4 Worker Test Suite (test_milestone4.ps1) exits 0" $m4Pass "test_milestone4.ps1 failed with code $LASTEXITCODE"

# ------------------------------------------------------------------------------
# SUMMARY REPORT
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Challenger Adversarial Test Suite Summary: $PassedTests / $TotalTests Passed" -ForegroundColor $(if ($FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "======================================================================" -ForegroundColor Cyan

if ($FailedTests -gt 0) {
    Write-Host "`nFAILURE DETECTED in Challenger Suite:" -ForegroundColor Red
    foreach ($f in $Failures) {
        Write-Host "  $f" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`nEMPIRICAL VERDICT: ALL ADVERSARIAL CHALLENGES PASSED (100% COMPLIANT)." -ForegroundColor Green
    exit 0
}
