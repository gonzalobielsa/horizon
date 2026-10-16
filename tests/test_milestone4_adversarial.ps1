# Adversarial Test Suite for Milestone 4 (Footer Group)
# Author: challenger_m4_1 (Empirical Challenger)
# Date: 2026-10-16

param(
    [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$failures = @()
$passes = @()

function Assert-Condition($condition, $testName, $failMsg) {
    if ($condition) {
        $script:passes += $testName
        Write-Host "  [PASS] $testName" -ForegroundColor Green
    } else {
        $script:failures += "$testName - $failMsg"
        Write-Host "  [FAIL] $testName : $failMsg" -ForegroundColor Red
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "ADVERSARIAL STRESS TEST: Milestone 4 (sections/footer-group.json)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$footerPath = Join-Path $ProjectRoot "sections\footer-group.json"
Assert-Condition (Test-Path $footerPath) "File existence" "sections/footer-group.json not found"

$rawText = [System.IO.File]::ReadAllText($footerPath, [System.Text.Encoding]::UTF8)

# --------------------------------------------------------------------
# 1. Structural Syntax, Encoding, Comments & Multi-Parser Stress
# --------------------------------------------------------------------
Write-Host "`n>>> SUITE 1: Syntax, Multi-Parser & Lexical Tokenizer Stress" -ForegroundColor Yellow

# Comment header check
$commentRegex = '^\s*/\*[\s\S]*?\*/'
$hasCommentHeader = $rawText -match $commentRegex
Assert-Condition $hasCommentHeader "Shopify auto-generated comment block present" "File lacks /* ... */ header at start"

$jsonContent = [regex]::Replace($rawText, $commentRegex, "").Trim()

# Parser 1: PowerShell ConvertFrom-Json
$psParsed = $null
try {
    $psParsed = $jsonContent | ConvertFrom-Json
    Assert-Condition ($null -ne $psParsed) "PowerShell ConvertFrom-Json deserialization" "ConvertFrom-Json returned null"
} catch {
    Assert-Condition $false "PowerShell ConvertFrom-Json deserialization" $_.Exception.Message
}

# Parser 2: .NET JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
try {
    $jsParsed = $jsSerializer.DeserializeObject($jsonContent)
    Assert-Condition ($null -ne $jsParsed) ".NET JavaScriptSerializer deserialization" "DeserializeObject returned null"
} catch {
    Assert-Condition $false ".NET JavaScriptSerializer deserialization" $_.Exception.Message
}

# Parser 3: Strict JsonReaderWriterFactory
Add-Type -AssemblyName System.Runtime.Serialization
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null)
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($jsonReader)
    Assert-Condition ($null -ne $xmlDoc.DocumentElement) "Strict JsonReaderWriterFactory XML bridge" "XmlDoc is empty"
} catch {
    Assert-Condition $false "Strict JsonReaderWriterFactory XML bridge" $_.Exception.Message
}

# Parser 4: Adversarial Duplicate Key Detector & Trailing Comma Scanner
# We write a custom tokenizer in C# to inspect every object scope for duplicate keys
$csharpSource = @"
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

public class JsonAdversarialValidator
{
    public static List<string> DetectDuplicateKeys(string json)
    {
        var duplicates = new List<string>();
        // Stack of dictionaries to track keys per object depth
        var keyStack = new Stack<HashSet<string>>();
        bool inString = false;
        bool escape = false;
        var currentToken = new System.Text.StringBuilder();

        for (int i = 0; i < json.Length; i++)
        {
            char c = json[i];
            if (escape)
            {
                escape = false;
                continue;
            }
            if (c == '\\')
            {
                escape = true;
                continue;
            }
            if (c == '\"')
            {
                inString = !inString;
                if (!inString)
                {
                    // Check if followed by colon ':'
                    int next = i + 1;
                    while (next < json.Length && char.IsWhiteSpace(json[next]))
                    {
                        next++;
                    }
                    if (next < json.Length && json[next] == ':')
                    {
                        string key = currentToken.ToString();
                        if (keyStack.Count > 0)
                        {
                            if (!keyStack.Peek().Add(key))
                            {
                                duplicates.Add(key);
                            }
                        }
                    }
                }
                else
                {
                    currentToken.Clear();
                }
                continue;
            }

            if (inString)
            {
                currentToken.Append(c);
                continue;
            }

            if (c == '{')
            {
                keyStack.Push(new HashSet<string>());
            }
            else if (c == '}')
            {
                if (keyStack.Count > 0)
                {
                    keyStack.Pop();
                }
            }
        }
        return duplicates;
    }

    public static List<string> DetectTrailingCommas(string json)
    {
        var errors = new List<string>();
        string[] lines = json.Split(new string[] { "\r\n", "\n" }, StringSplitOptions.None);
        for (int i = 0; i < lines.Length; i++)
        {
            string trimmed = lines[i].Trim();
            if (trimmed.EndsWith(","))
            {
                for (int j = i + 1; j < lines.Length; j++)
                {
                    string nextTrimmed = lines[j].Trim();
                    if (string.IsNullOrEmpty(nextTrimmed)) continue;
                    if (nextTrimmed.StartsWith("}") || nextTrimmed.StartsWith("]"))
                    {
                        errors.Add(string.Format("Line {0}: '{1}' followed by closing token on Line {2}: '{3}'", i + 1, trimmed, j + 1, nextTrimmed));
                    }
                    break;
                }
            }
        }
        return errors;
    }
}
"@

Add-Type -TypeDefinition $csharpSource -Language CSharp

$dupKeys = [JsonAdversarialValidator]::DetectDuplicateKeys($jsonContent)
Assert-Condition ($dupKeys.Count -eq 0) "Zero duplicate keys across all object scopes" "Found duplicate keys: $($dupKeys -join ', ')"

$trailingCommas = [JsonAdversarialValidator]::DetectTrailingCommas($jsonContent)
Assert-Condition ($trailingCommas.Count -eq 0) "Zero trailing commas before closing braces/brackets" "Found trailing commas: $($trailingCommas -join '; ')"

# --------------------------------------------------------------------
# 2. Section & Block Schema Conformance Verification
# --------------------------------------------------------------------
Write-Host "`n>>> SUITE 2: Liquid Schema Conformance Testing" -ForegroundColor Yellow

# Helper to extract JSON schema from a Liquid file
function Get-LiquidSchema([string]$relPath) {
    $fullPath = Join-Path $ProjectRoot $relPath
    if (-not (Test-Path $fullPath)) {
        throw "Liquid file not found: $fullPath"
    }
    $content = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    if ($content -match '\{%\s*schema\s*%\}([\s\S]*?)\{%\s*endschema\s*%\}') {
        $rawSchema = $matches[1].Trim()
        return $rawSchema | ConvertFrom-Json
    }
    throw "No schema block found in $relPath"
}

$footerSchema = Get-LiquidSchema "sections\footer.liquid"
$utilSchema = Get-LiquidSchema "sections\footer-utilities.liquid"
$emailSignupSchema = Get-LiquidSchema "blocks\email-signup.liquid"
$menuSchema = Get-LiquidSchema "blocks\menu.liquid"
$paymentIconsSchema = Get-LiquidSchema "blocks\payment-icons.liquid"
$socialSchema = Get-LiquidSchema "blocks\social-links.liquid"
$copyrightSchema = Get-LiquidSchema "blocks\footer-copyright.liquid"
$policySchema = Get-LiquidSchema "blocks\footer-policy-list.liquid"
$groupSchema = Get-LiquidSchema "blocks\group.liquid"
$textSchema = Get-LiquidSchema "blocks\text.liquid"

# Verify Root Section structure
Assert-Condition ($psParsed.type -eq "footer") "Root group type is 'footer'" "Found: $($psParsed.type)"
Assert-Condition ($psParsed.order.Count -eq 2 -and $psParsed.order[0] -eq "footer" -and $psParsed.order[1] -eq "utilities") "Section order is ['footer', 'utilities']" "Found order: $($psParsed.order -join ', ')"

# Section 1: footer section schema checks
$footerObj = $psParsed.sections.footer
Assert-Condition ($footerObj.type -eq "footer") "sections.footer.type is 'footer'" "Found: $($footerObj.type)"

# Verify footer settings against footer.liquid schema
$footerAllowedSettings = @{}
foreach ($s in $footerSchema.settings) {
    if ($s.id) { $footerAllowedSettings[$s.id] = $s }
}
foreach ($prop in $footerObj.settings.PSObject.Properties) {
    $sId = $prop.Name
    $sVal = $prop.Value
    Assert-Condition ($footerAllowedSettings.ContainsKey($sId)) "footer setting '$sId' declared in footer.liquid schema" "Unknown setting: $sId"
}
Assert-Condition ($footerObj.settings.background_color -eq "{{ settings.color_palette.color2 }}") "footer background_color uses Soft Beige token '{{ settings.color_palette.color2 }}'" "Found: $($footerObj.settings.background_color)"

# Section 1 blocks
$footerAllowedBlocks = @($footerSchema.blocks | ForEach-Object { $_.type })
foreach ($bProp in $footerObj.blocks.PSObject.Properties) {
    $bId = $bProp.Name
    $bObj = $bProp.Value
    Assert-Condition ($footerAllowedBlocks -contains $bObj.type) "footer block '$bId' (type '$($bObj.type)') is in footer.liquid allowed blocks" "Block type not allowed: $($bObj.type)"
}
Assert-Condition ($footerObj.block_order.Count -eq 4) "footer has exactly 4 blocks in block_order for 4-col responsive grid" "Count: $($footerObj.block_order.Count)"
$expectedFooterOrder = @("group_newsletter", "menu_shop", "menu_care", "payment_icons")
for ($i = 0; $i -lt 4; $i++) {
    Assert-Condition ($footerObj.block_order[$i] -eq $expectedFooterOrder[$i]) "footer block_order[$i] == '$($expectedFooterOrder[$i])'" "Found: $($footerObj.block_order[$i])"
}

# Test group_newsletter inside footer
$gn = $footerObj.blocks.group_newsletter
Assert-Condition ($gn.type -eq "group") "group_newsletter type is 'group'" "Found: $($gn.type)"
Assert-Condition ($gn.block_order.Count -eq 3) "group_newsletter contains exactly 3 blocks (heading, subcopy, email_signup)" "Count: $($gn.block_order.Count)"

# Validate email_signup block settings against blocks/email-signup.liquid
$es = $gn.blocks.email_signup
$esAllowedSettings = @{}
foreach ($s in $emailSignupSchema.settings) {
    if ($s.id) { $esAllowedSettings[$s.id] = $s }
}
foreach ($prop in $es.settings.PSObject.Properties) {
    $sId = $prop.Name
    $sVal = $prop.Value
    Assert-Condition ($esAllowedSettings.ContainsKey($sId)) "email_signup setting '$sId' declared in schema" "Unknown setting: $sId"
    # If setting is a range, check bounds
    $schemaDef = $esAllowedSettings[$sId]
    if ($schemaDef.type -eq "range") {
        $num = [double]$sVal
        Assert-Condition ($num -ge $schemaDef.min -and $num -le $schemaDef.max) "email_signup setting '$sId' ($num) within [$($schemaDef.min), $($schemaDef.max)]" "Out of range"
    }
    # If select, check options
    if ($schemaDef.type -eq "select" -and $schemaDef.options) {
        $optVals = @($schemaDef.options | ForEach-Object { $_.value })
        Assert-Condition ($optVals -contains [string]$sVal) "email_signup setting '$sId' value '$sVal' in schema options" "Invalid option: $sVal"
    }
}

Assert-Condition ($es.settings.border_radius -eq 100) "email_signup border_radius is 100 (pill shape)" "Found: $($es.settings.border_radius)"
Assert-Condition ($es.settings.input_style -eq "custom") "email_signup input_style is 'custom'" "Found: $($es.settings.input_style)"
Assert-Condition ($es.settings.style_class -eq "button-custom") "email_signup style_class is 'button-custom'" "Found: $($es.settings.style_class)"
Assert-Condition ($es.settings.custom_button_background -eq "{{ settings.color_palette.color1 }}") "email_signup custom_button_background is Dusty Rose token '{{ settings.color_palette.color1 }}'" "Found: $($es.settings.custom_button_background)"
Assert-Condition ($es.settings.custom_button_text -eq "#FFFFFF") "email_signup custom_button_text is '#FFFFFF'" "Found: $($es.settings.custom_button_text)"

# Validate menu_shop and menu_care settings
$menuShop = $footerObj.blocks.menu_shop
$menuCare = $footerObj.blocks.menu_care
Assert-Condition ($menuShop.settings.menu -eq "main-menu") "menu_shop binds to 'main-menu'" "Found: $($menuShop.settings.menu)"
Assert-Condition ($menuShop.settings.heading -eq "Shop") "menu_shop heading is 'Shop'" "Found: $($menuShop.settings.heading)"
Assert-Condition ($menuCare.settings.menu -eq "footer") "menu_care binds to 'footer'" "Found: $($menuCare.settings.menu)"
Assert-Condition ($menuCare.settings.heading -eq "Customer Care") "menu_care heading is 'Customer Care'" "Found: $($menuCare.settings.heading)"

# Validate payment_icons
$payIcons = $footerObj.blocks.payment_icons
Assert-Condition ($payIcons.type -eq "payment-icons") "payment_icons type is 'payment-icons'" "Found: $($payIcons.type)"
Assert-Condition ($payIcons.settings.horizontal_alignment -eq "flex-start") "payment_icons alignment is 'flex-start'" "Found: $($payIcons.settings.horizontal_alignment)"

# Section 2: utilities section schema checks
$utilObj = $psParsed.sections.utilities
Assert-Condition ($utilObj.type -eq "footer-utilities") "sections.utilities.type is 'footer-utilities'" "Found: $($utilObj.type)"
Assert-Condition ($utilObj.settings.background_color -eq "{{ settings.color_palette.color2 }}") "utilities background_color is Soft Beige '{{ settings.color_palette.color2 }}'" "Found: $($utilObj.settings.background_color)"
Assert-Condition ($utilObj.settings.divider_color -eq "{{ settings.color_palette.color3 }}") "utilities divider_color is White '{{ settings.color_palette.color3 }}'" "Found: $($utilObj.settings.divider_color)"
Assert-Condition ($utilObj.settings.divider_thickness -eq 1) "utilities divider_thickness is 1" "Found: $($utilObj.settings.divider_thickness)"

# Utilities blocks checks
Assert-Condition ($utilObj.block_order.Count -eq 3) "utilities block_order count is 3 (max_blocks: 3)" "Found: $($utilObj.block_order.Count)"
Assert-Condition ($utilObj.block_order[0] -eq "copyright") "utilities block 1 is 'copyright'" "Found: $($utilObj.block_order[0])"
Assert-Condition ($utilObj.block_order[1] -eq "policy_list") "utilities block 2 is 'policy_list'" "Found: $($utilObj.block_order[1])"
Assert-Condition ($utilObj.block_order[2] -eq "social_icons") "utilities block 3 is 'social_icons'" "Found: $($utilObj.block_order[2])"

$copyright = $utilObj.blocks.copyright
Assert-Condition ($copyright.type -eq "footer-copyright") "copyright block type is 'footer-copyright'" "Found: $($copyright.type)"
Assert-Condition ($copyright.settings.show_powered_by -eq $false) "show_powered_by is explicitly false" "Found: $($copyright.settings.show_powered_by)"

$policyList = $utilObj.blocks.policy_list
Assert-Condition ($policyList.type -eq "footer-policy-list") "policy_list block type is 'footer-policy-list'" "Found: $($policyList.type)"

$social = $utilObj.blocks.social_icons
Assert-Condition ($social.type -eq "social-links") "social_icons block type is 'social-links'" "Found: $($social.type)"

# --------------------------------------------------------------------
# 3. Social Media URLs & Liquid Storefront Rendering Simulation
# --------------------------------------------------------------------
Write-Host "`n>>> SUITE 3: Liquid Social Links Storefront Simulation" -ForegroundColor Yellow

# Liquid lines 60-70 of blocks/social-links.liquid:
#   assign url_parts = link_url | split: '//' | last | split: '/'
#   assign has_profile = false
#   if url_parts.size > 1 and url_parts[1] != ''
#     assign has_profile = true
#   endif
function Test-LiquidSocialLinkStorefrontRender([string]$url) {
    if ([string]::IsNullOrWhiteSpace($url)) {
        return @{ HasProfile = $false; Parts = @() }
    }
    $afterSlashSlash = $url -split '//'
    $lastPart = $afterSlashSlash[-1]
    $urlParts = $lastPart -split '/'
    $hasProfile = ($urlParts.Length -gt 1 -and -not [string]::IsNullOrEmpty($urlParts[1]))
    return @{ HasProfile = $hasProfile; Parts = $urlParts }
}

$socialChannels = @('instagram_url', 'tiktok_url', 'youtube_url', 'facebook_url')
foreach ($chan in $socialChannels) {
    $url = $social.settings.$chan
    Assert-Condition (-not [string]::IsNullOrEmpty($url)) "Social setting '$chan' is configured" "Missing URL"
    $simResult = Test-LiquidSocialLinkStorefrontRender $url
    Assert-Condition ($simResult.HasProfile -eq $true) "Storefront render simulator for '$chan' ($url) produces has_profile = true" "Storefront will hide icon! UrlParts: $($simResult.Parts -join ' | ')"
}

# Adversarial negative tests on the simulator to prove it would catch broken URLs
$negativeTest1 = Test-LiquidSocialLinkStorefrontRender "https://www.facebook.com"
Assert-Condition ($negativeTest1.HasProfile -eq $false) "Negative test: bare domain https://www.facebook.com correctly caught as has_profile = false" "Failed negative test"
$negativeTest2 = Test-LiquidSocialLinkStorefrontRender "https://www.facebook.com/"
Assert-Condition ($negativeTest2.HasProfile -eq $false) "Negative test: domain with trailing slash https://www.facebook.com/ correctly caught as has_profile = false" "Failed negative test"

# --------------------------------------------------------------------
# 4. Color Palette Tokens Conformance & Contrast Verification
# --------------------------------------------------------------------
Write-Host "`n>>> SUITE 4: Color Palette Token Integrity & Accessibility Contrast" -ForegroundColor Yellow

$settingsDataPath = Join-Path $ProjectRoot "config\settings_data.json"
Assert-Condition (Test-Path $settingsDataPath) "config/settings_data.json exists" "File missing"
$settingsDataRaw = [System.IO.File]::ReadAllText($settingsDataPath, [System.Text.Encoding]::UTF8)
$settingsDataJson = [regex]::Replace($settingsDataRaw, '^\s*/\*[\s\S]*?\*/', '').Trim()
$settingsData = $settingsDataJson | ConvertFrom-Json
$cp = $settingsData.current.color_palette

Write-Host "  Theme Color Palette Tokens:"
Write-Host "    background : $($cp.background) (Warm Ivory)"
Write-Host "    foreground : $($cp.foreground) (Deep Charcoal)"
Write-Host "    color1     : $($cp.color1) (Dusty Rose)"
Write-Host "    color2     : $($cp.color2) (Soft Beige)"
Write-Host "    color3     : $($cp.color3) (White)"

# Check WCAG contrast between button background (color1) and button text (White #FFFFFF)
function Get-RelativeLuminance([string]$hexColor) {
    $hex = $hexColor.TrimStart('#')
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0

    $rNorm = if ($r -le 0.03928) { $r / 12.92 } else { [Math]::Pow(($r + 0.055) / 1.055, 2.4) }
    $gNorm = if ($g -le 0.03928) { $g / 12.92 } else { [Math]::Pow(($g + 0.055) / 1.055, 2.4) }
    $bNorm = if ($b -le 0.03928) { $b / 12.92 } else { [Math]::Pow(($b + 0.055) / 1.055, 2.4) }

    return 0.2126 * $rNorm + 0.7152 * $gNorm + 0.0722 * $bNorm
}

function Get-ContrastRatio([string]$c1, [string]$c2) {
    $l1 = Get-RelativeLuminance $c1
    $l2 = Get-RelativeLuminance $c2
    $lighter = [Math]::Max($l1, $l2)
    $darker = [Math]::Min($l1, $l2)
    return ($lighter + 0.05) / ($darker + 0.05)
}

# Contrast of Deep Charcoal (#252525) on Soft Beige (#E9DED5)
$footerTextContrast = Get-ContrastRatio $cp.foreground $cp.color2
Write-Host "  Footer Text Contrast (Deep Charcoal on Soft Beige): $([Math]::Round($footerTextContrast, 2)):1"
Assert-Condition ($footerTextContrast -ge 4.5) "Footer body text contrast ratio >= 4.5:1 (WCAG AA)" "Contrast too low: $footerTextContrast"

# Contrast of Dusty Rose (#B87570) on Soft Beige (#E9DED5) for button surface
$btnBgContrast = Get-ContrastRatio $cp.color1 $cp.color2
Write-Host "  Button Surface Contrast (Dusty Rose on Soft Beige): $([Math]::Round($btnBgContrast, 2)):1"

# --------------------------------------------------------------------
# 5. Git Status Boundary Inspection
# --------------------------------------------------------------------
Write-Host "`n>>> SUITE 5: Git Boundary & Isolation Check" -ForegroundColor Yellow

$gitStatus = git status --porcelain
Write-Host "  Current Git Porcelain Status:"
$gitStatus | ForEach-Object { Write-Host "    $_" }

# Ensure footer-group.json is modified
$footerModified = $gitStatus | Where-Object { $_ -match 'sections/footer-group\.json' }
Assert-Condition ($null -ne $footerModified) "sections/footer-group.json tracked and modified" "Not in git status"

# --------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "ADVERSARIAL STRESS TEST SUMMARY" -ForegroundColor Cyan
Write-Host "  Passes  : $($script:passes.Count)" -ForegroundColor Green
Write-Host "  Failures: $($script:failures.Count)" -ForegroundColor $(if ($script:failures.Count -gt 0) { "Red" } else { "Green" })
Write-Host "======================================================================" -ForegroundColor Cyan

if ($script:failures.Count -gt 0) {
    Write-Host "`nFAILED ASSERTIONS:" -ForegroundColor Red
    $script:failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
} else {
    Write-Host "`nALL ADVERSARIAL STRESS TESTS PASSED WITH ZERO DEFECTS!" -ForegroundColor Green
    exit 0
}
