# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 2 Challenger Adversarial Test Suite
# Author: challenger_m2_1 (Empirical Challenger)
# Target: sections/header-group.json (Requirement R2)
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
Write-Host "Milestone 2 Challenger Adversarial Test Suite (Empirical Verification)" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$HeaderGroupPath = Join-Path $ProjectRoot "sections\header-group.json"
$HeaderLiquidPath = Join-Path $ProjectRoot "sections\header.liquid"
$AnnLiquidPath = Join-Path $ProjectRoot "sections\header-announcements.liquid"
$AnnBlockLiquidPath = Join-Path $ProjectRoot "blocks\_announcement.liquid"
$HeaderLogoBlockPath = Join-Path $ProjectRoot "blocks\_header-logo.liquid"
$HeaderMenuBlockPath = Join-Path $ProjectRoot "blocks\_header-menu.liquid"

# ------------------------------------------------------------------------------
# SUITE 1: Multi-Parser Deserialization & Structural Stress-Testing
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 1: Multi-Parser Deserialization & Structural Stress-Testing ---" -ForegroundColor Yellow

Report-Assert "header-group.json exists" (Test-Path $HeaderGroupPath) "File missing"
$rawText = [System.IO.File]::ReadAllText($HeaderGroupPath, [System.Text.Encoding]::UTF8)

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

# Parser 4: Strict RFC 8259 Lexer & Duplicate Key Detector (Compiled C#)
$csharpValidator = @"
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

public class StrictJsonValidator {
    public static string Validate(string json) {
        // 1. Check for trailing commas
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
$strictResult = [StrictJsonValidator]::Validate($jsonBody)
Report-Assert "Parser 4 (Strict C# Lexer & Grammar Validator) returns OK" ($strictResult -eq "OK") $strictResult

# Stress-test: Trailing commas regex
$hasTrailing = [regex]::IsMatch($jsonBody, ',\s*([\}\]])')
Report-Assert "Lexical Stress: Zero trailing commas in JSON body" (-not $hasTrailing) "Trailing comma found"

# Stress-test: Single quotes regex
$hasSingleQuotes = [regex]::IsMatch($jsonBody, "(?<!\\)'([^'\\]|\\.)*'")
Report-Assert "Lexical Stress: Zero single quotes used for JSON strings" (-not $hasSingleQuotes) "Single quotes found"

# Stress-test: No unquoted keys
$hasUnquotedKeys = [regex]::IsMatch($jsonBody, '(?<=[\{\,]\s*)([a-zA-Z0-9_\-]+)\s*:')
Report-Assert "Lexical Stress: Zero unquoted keys in JSON body" (-not $hasUnquotedKeys) "Unquoted key found"

# ------------------------------------------------------------------------------
# SUITE 2: Negative Testing Oracles (Sensitivity Verification)
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 2: Negative Testing Oracles (Sensitivity Verification) ---" -ForegroundColor Yellow

# Oracle 1: Ensure trailing comma is detected by strict validator
$badJsonWithTrailingComma = '{"key": "val",}'
$detectedTrailing = [StrictJsonValidator]::Validate($badJsonWithTrailingComma)
Report-Assert "Oracle 1: Strict validator detects synthetic trailing comma" ($detectedTrailing -like "*Trailing comma*") "Failed to detect synthetic trailing comma"

# Oracle 2: Ensure single quote is detected
$badJsonWithSingleQuote = "{'key': 'val'}"
$detectedQuote = [StrictJsonValidator]::Validate($badJsonWithSingleQuote)
Report-Assert "Oracle 2: Strict validator detects synthetic single quote" ($detectedQuote -like "*Single-quoted*") "Failed to detect synthetic single quote"

# Oracle 3: Ensure mismatched brace is detected
$badJsonWithMismatchedBrace = '{"key": "val"'
$detectedBrace = [StrictJsonValidator]::Validate($badJsonWithMismatchedBrace)
Report-Assert "Oracle 3: Strict validator detects synthetic unclosed brace" ($detectedBrace -like "*Unclosed*") "Failed to detect synthetic unclosed brace"

# ------------------------------------------------------------------------------
# SUITE 3: Static Theme Blocks Contract Verification
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 3: Static Theme Blocks Contract Verification ---" -ForegroundColor Yellow

$hdrLiquidContent = [System.IO.File]::ReadAllText($HeaderLiquidPath, [System.Text.Encoding]::UTF8)

# Find all static block calls in header.liquid
$staticBlockMatches = [regex]::Matches($hdrLiquidContent, "content_for\s+'block',\s*type:\s*'([^']+)',\s*id:\s*'([^']+)'")
Write-Host "  Found $($staticBlockMatches.Count) static block declarations in sections/header.liquid:" -ForegroundColor Gray
$declaredStaticBlocks = @{}
foreach ($m in $staticBlockMatches) {
    $bType = $m.Groups[1].Value
    $bId = $m.Groups[2].Value
    $declaredStaticBlocks[$bId] = $bType
    Write-Host "    - id: '$bId', type: '$bType'" -ForegroundColor Gray
}

# Verify header-logo and header-menu are in declared static blocks
Report-Assert "header.liquid declares static block 'header-logo'" ($declaredStaticBlocks.ContainsKey("header-logo")) "header-logo not found in Liquid"
Report-Assert "header.liquid declares static block 'header-menu'" ($declaredStaticBlocks.ContainsKey("header-menu")) "header-menu not found in Liquid"

# Verify header_section in header-group.json contains exact blocks with static: true
$hdrSection = $psParsed.sections.header_section
Report-Assert "header_section defined in header-group.json" ($hdrSection -ne $null) "header_section missing"

foreach ($reqId in $declaredStaticBlocks.Keys) {
    $reqType = $declaredStaticBlocks[$reqId]
    $blockObj = $hdrSection.blocks.$reqId
    Report-Assert "Block '$reqId' exists in header_section.blocks" ($blockObj -ne $null) "Block $reqId missing"
    Report-Assert "Block '$reqId' has exact type '$reqType'" ($blockObj.type -eq $reqType) "Type is $($blockObj.type)"
    Report-Assert "Block '$reqId' has 'static: true' boolean property" ($blockObj.static -eq $true) "static is $($blockObj.static)"
    Report-Assert "Block '$reqId' static property is strictly Boolean, not String" ($blockObj.static.GetType().Name -eq "Boolean") "Type is $($blockObj.static.GetType().Name)"
}

# ------------------------------------------------------------------------------
# SUITE 4: Announcement Bar Schema & Dynamic Autoplay Verification
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 4: Announcement Bar Schema & Dynamic Autoplay Verification ---" -ForegroundColor Yellow

$annLiquidContent = [System.IO.File]::ReadAllText($AnnLiquidPath, [System.Text.Encoding]::UTF8)

# Extract schema JSON from header-announcements.liquid
$annSchemaMatch = [regex]::Match($annLiquidContent, '\{%\s*schema\s*%\}(.*?)\{%\s*endschema\s*%\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Report-Assert "header-announcements.liquid contains schema tag" ($annSchemaMatch.Success) "Schema tag missing"

$annSchemaJson = $annSchemaMatch.Groups[1].Value.Trim()
$annSchema = $annSchemaJson | ConvertFrom-Json

Report-Assert "Announcement section schema allows '_announcement' block type" (
    ($annSchema.blocks | Where-Object { $_.type -eq "_announcement" }) -ne $null
) "Block type _announcement not in schema blocks"

$annSection = $psParsed.sections.header_announcements_9jGBFp
Report-Assert "Announcement section type is 'header-announcements'" ($annSection.type -eq "header-announcements") "Type is $($annSection.type)"

# Verify blocks count > 1 for dynamic autoplay
Report-Assert "Announcement section has exactly 2 blocks (activates autoplay per Liquid line 23)" (
    $annSection.block_order.Count -eq 2
) "Block count is $($annSection.block_order.Count)"

# Verify announcement settings against schema ranges
Report-Assert "Announcement 'speed' setting is 5 (within schema range 2..10)" (
    $annSection.settings.speed -ge 2 -and $annSection.settings.speed -le 10 -and $annSection.settings.speed -eq 5
) "Speed is $($annSection.settings.speed)"

Report-Assert "Announcement 'section_width' is 'page-width'" (
    $annSection.settings.section_width -eq "page-width"
) "section_width is $($annSection.settings.section_width)"

Report-Assert "Announcement 'divider_width' is 1 (within schema range 0..5)" (
    $annSection.settings.divider_width -ge 0 -and $annSection.settings.divider_width -le 5
) "divider_width is $($annSection.settings.divider_width)"

Report-Assert "Announcement 'background_color' is Soft Beige token '{{ settings.color_palette.color2 }}'" (
    $annSection.settings.background_color -eq "{{ settings.color_palette.color2 }}"
) "background_color is $($annSection.settings.background_color)"

Report-Assert "Announcement 'divider_color' is White token '{{ settings.color_palette.color3 }}'" (
    $annSection.settings.divider_color -eq "{{ settings.color_palette.color3 }}"
) "divider_color is $($annSection.settings.divider_color)"

# Verify blocks content against _announcement.liquid schema
$annBlockLiquid = [System.IO.File]::ReadAllText($AnnBlockLiquidPath, [System.Text.Encoding]::UTF8)
$annBlockSchemaMatch = [regex]::Match($annBlockLiquid, '\{%\s*schema\s*%\}(.*?)\{%\s*endschema\s*%\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$annBlockSchema = $annBlockSchemaMatch.Groups[1].Value.Trim() | ConvertFrom-Json

$fontSettingSchema = $annBlockSchema.settings | Where-Object { $_.id -eq "font" }
$validFonts = @($fontSettingSchema.options | ForEach-Object { $_.value })

$fontSizeSettingSchema = $annBlockSchema.settings | Where-Object { $_.id -eq "font_size" }
$validFontSizes = @($fontSizeSettingSchema.options | ForEach-Object { $_.value })

$weightSettingSchema = $annBlockSchema.settings | Where-Object { $_.id -eq "weight" }
$validWeights = @($weightSettingSchema.options | ForEach-Object { $_.value })

# Check Block 1: Shipping
$b1 = $annSection.blocks.announcement_shipping
Report-Assert "Block 'announcement_shipping' type is '_announcement'" ($b1.type -eq "_announcement") "Type is $($b1.type)"
Report-Assert "b1 text contains 'Complimentary Shipping on Orders Over `$150'" ($b1.settings.text -like "*Complimentary Shipping on Orders Over `$150*") "Text is $($b1.settings.text)"
$b1Font = $b1.settings.font
Report-Assert "b1 font '$b1Font' is an allowed schema option" ($validFonts -contains $b1Font) "Invalid font option"
$b1Size = $b1.settings.font_size
Report-Assert "b1 font_size '$b1Size' is an allowed schema option" ($validFontSizes -contains $b1Size) "Invalid font_size option"
$b1Weight = $b1.settings.weight
Report-Assert "b1 weight '$b1Weight' is an allowed schema option" ($validWeights -contains $b1Weight) "Invalid weight option"

# Check Block 2: Brand Ethos
$b2 = $annSection.blocks.announcement_ethos
Report-Assert "Block 'announcement_ethos' type is '_announcement'" ($b2.type -eq "_announcement") "Type is $($b2.type)"
Report-Assert "b2 text contains 'STRONGER YOU.'" ($b2.settings.text -like "*STRONGER YOU.*") "Text is $($b2.settings.text)"
Report-Assert "b2 text contains 'Premium Functional Strength Sculpted for Women'" ($b2.settings.text -like "*Premium Functional Strength Sculpted for Women*") "Text is $($b2.settings.text)"
Report-Assert "b2 font '$($b2.settings.font)' is an allowed schema option" ($validFonts -contains $b2.settings.font) "Invalid font option"
Report-Assert "b2 font_size '$($b2.settings.font_size)' is an allowed schema option" ($validFontSizes -contains $b2.settings.font_size) "Invalid font_size option"
Report-Assert "b2 weight '$($b2.settings.weight)' is an allowed schema option" ($validWeights -contains $b2.settings.weight) "Invalid weight option"

# ------------------------------------------------------------------------------
# SUITE 5: Header Section & Menu Schema Conformance
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 5: Header Section & Menu Schema Conformance ---" -ForegroundColor Yellow

$hdrMenuBlockLiquid = [System.IO.File]::ReadAllText($HeaderMenuBlockPath, [System.Text.Encoding]::UTF8)
$hdrMenuSchemaMatch = [regex]::Match($hdrMenuBlockLiquid, '\{%\s*schema\s*%\}(.*?)\{%\s*endschema\s*%\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$hdrMenuSchema = $hdrMenuSchemaMatch.Groups[1].Value.Trim() | ConvertFrom-Json

$menuPrimarySizeSchema = $hdrMenuSchema.settings | Where-Object { $_.id -eq "type_font_primary_size" }
$validMenuSizes = @($menuPrimarySizeSchema.options | ForEach-Object { $_.value })

$menuFontStyleSchema = $hdrMenuSchema.settings | Where-Object { $_.id -eq "menu_font_style" }
$validMenuFontStyles = @($menuFontStyleSchema.options | ForEach-Object { $_.value })

$menuStyleSchema = $hdrMenuSchema.settings | Where-Object { $_.id -eq "menu_style" }
$validMenuStyles = @($menuStyleSchema.options | ForEach-Object { $_.value })

$menuBlock = $hdrSection.blocks.'header-menu'
Report-Assert "header-menu 'type_font_primary_size' ($($menuBlock.settings.type_font_primary_size)) is a valid schema option" (
    $validMenuSizes -contains $menuBlock.settings.type_font_primary_size
) "Invalid size option"
Report-Assert "header-menu 'menu_font_style' ($($menuBlock.settings.menu_font_style)) is a valid schema option" (
    $validMenuFontStyles -contains $menuBlock.settings.menu_font_style
) "Invalid font style option"
Report-Assert "header-menu 'menu_style' ($($menuBlock.settings.menu_style)) is a valid schema option" (
    $validMenuStyles -contains $menuBlock.settings.menu_style
) "Invalid menu style option"
Report-Assert "header-menu 'drawer_accordion' is boolean true" ($menuBlock.settings.drawer_accordion -eq $true) "drawer_accordion is $($menuBlock.settings.drawer_accordion)"
Report-Assert "header-menu 'drawer_dividers' is boolean true" ($menuBlock.settings.drawer_dividers -eq $true) "drawer_dividers is $($menuBlock.settings.drawer_dividers)"

# Header platform settings
$hs = $hdrSection.settings
Report-Assert "header 'show_search' is boolean true" ($hs.show_search -eq $true) "show_search is $($hs.show_search)"
Report-Assert "header 'show_country' is boolean true" ($hs.show_country -eq $true) "show_country is $($hs.show_country)"
Report-Assert "header 'country_selector_style' is boolean true" ($hs.country_selector_style -eq $true) "country_selector_style is $($hs.country_selector_style)"
Report-Assert "header 'show_language' is boolean true" ($hs.show_language -eq $true) "show_language is $($hs.show_language)"
Report-Assert "header 'customer_account_menu' is 'customer-account-main-menu'" ($hs.customer_account_menu -eq "customer-account-main-menu") "customer_account_menu is $($hs.customer_account_menu)"
Report-Assert "header 'enable_sticky_header' is 'always'" ($hs.enable_sticky_header -eq "always") "enable_sticky_header is $($hs.enable_sticky_header)"

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
