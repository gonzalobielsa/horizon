# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 4 Forensic Integrity & Adversarial Audit Suite
# Auditor: auditor_m4_1 (Critic, Specialist, Auditor)
# Target: sections/footer-group.json
# Requirements: R4 (Footer Group) & Project Plan Milestone 4
# ==============================================================================

param(
    [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$TotalChecks = 0
$PassedChecks = 0
$FailedChecks = 0
$Violations = @()

function Assert-Audit($Name, $Condition, $Detail = "") {
    $script:TotalChecks++
    if ($Condition) {
        $script:PassedChecks++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:FailedChecks++
        $msg = "  [FAIL] ${Name}: $Detail"
        $script:Violations += $msg
        Write-Host $msg -ForegroundColor Red
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 4 Forensic Integrity & Adversarial Audit Suite" -ForegroundColor Cyan
Write-Host "Target: sections/footer-group.json" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$FooterJsonPath = Join-Path $ProjectRoot "sections\footer-group.json"
Assert-Audit "File existence: sections/footer-group.json" (Test-Path $FooterJsonPath) "File not found"

if (-not (Test-Path $FooterJsonPath)) {
    Write-Host "CRITICAL: Cannot proceed without sections/footer-group.json" -ForegroundColor Red
    exit 1
}

$rawText = [System.IO.File]::ReadAllText($FooterJsonPath, [System.Text.Encoding]::UTF8)

# ------------------------------------------------------------------------------
# 1. Structural, Lexical & Multi-Parser Deserialization
# ------------------------------------------------------------------------------
Write-Host "`n--- 1. Structural, Lexical & Multi-Parser Deserialization ---" -ForegroundColor Yellow

# Comment Header Check
$commentRegex = '^\s*/\*\s*\r?\n\s*\*\s*--+.*?IMPORTANT: The contents of this file are auto-generated\..*?\*/'
$commentMatch = [regex]::Match($rawText, $commentRegex, [System.Text.RegularExpressions.RegexOptions]::Singleline)
Assert-Audit "Shopify auto-generated comment header is present and valid" ($commentMatch.Success) "Comment header missing or malformed"

$jsonBody = if ($commentMatch.Success) {
    $rawText.Substring($commentMatch.Index + $commentMatch.Length).Trim()
} else {
    $rawText.Trim()
}

# Parser 1: PowerShell ConvertFrom-Json
$parsed = $null
try {
    $parsed = $jsonBody | ConvertFrom-Json
    Assert-Audit "Parser 1: PowerShell ConvertFrom-Json" ($parsed -ne $null) ""
} catch {
    Assert-Audit "Parser 1: PowerShell ConvertFrom-Json" $false $_.Exception.Message
}

# Parser 2: .NET JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
try {
    $netParsed = $jsSerializer.DeserializeObject($jsonBody)
    Assert-Audit "Parser 2: .NET JavaScriptSerializer" ($netParsed -ne $null) ""
} catch {
    Assert-Audit "Parser 2: .NET JavaScriptSerializer" $false $_.Exception.Message
}

# Parser 3: Strict JsonReaderWriterFactory
Add-Type -AssemblyName System.Runtime.Serialization
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $reader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null)
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($reader)
    Assert-Audit "Parser 3: Strict JsonReaderWriterFactory" ($xmlDoc -ne $null) ""
} catch {
    Assert-Audit "Parser 3: Strict JsonReaderWriterFactory" $false $_.Exception.Message
}

# Trailing comma inspection
$lines = $jsonBody -split '\r?\n'
$hasTrailing = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match ',$' -and ($i + 1 -lt $lines.Length)) {
        $nextLine = $lines[$i + 1].Trim()
        if ($nextLine -match '^\s*[}\]]') {
            $hasTrailing = $true
            Write-Host "    Found trailing comma at line $($i+1): $line" -ForegroundColor Red
        }
    }
}
Assert-Audit "Syntax cleanliness: Zero trailing commas" (-not $hasTrailing) "Trailing comma detected"

# Duplicate key detection
$duplicateKeysFound = $false
function Check-DuplicateKeys($jsonStr) {
    # Scan for duplicate property names within the same object scope
    $depth = 0
    $scopeKeys = @{}
    $lines = $jsonStr -split '\r?\n'
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '\{') {
            $depth++
            $scopeKeys[$depth] = @()
        }
        if ($trimmed -match '"([^"]+)"\s*:') {
            $key = $matches[1]
            if ($scopeKeys.ContainsKey($depth)) {
                if ($scopeKeys[$depth] -contains $key) {
                    Write-Host "    Duplicate key detected at depth $($depth): $key" -ForegroundColor Red
                    return $true
                }
                $scopeKeys[$depth] += $key
            }
        }
        if ($trimmed -match '\}') {
            if ($scopeKeys.ContainsKey($depth)) {
                $scopeKeys.Remove($depth)
            }
            $depth--
        }
    }
    return $false
}
$duplicateKeysFound = Check-DuplicateKeys $jsonBody
Assert-Audit "Syntax cleanliness: Zero duplicate keys" (-not $duplicateKeysFound) "Duplicate JSON keys found"

# ------------------------------------------------------------------------------
# 2. Schema Structure & Ordering Forensics
# ------------------------------------------------------------------------------
Write-Host "`n--- 2. Schema Structure & Ordering Forensics ---" -ForegroundColor Yellow

Assert-Audit "Root type is 'footer'" ($parsed.type -eq "footer") "Got '$($parsed.type)'"
Assert-Audit "Root name is 't:names.footer'" ($parsed.name -eq "t:names.footer") "Got '$($parsed.name)'"

$expectedSections = @("footer", "utilities")
$actualSections = $parsed.order
$orderMatch = ($actualSections.Count -eq 2) -and ($actualSections[0] -eq "footer") -and ($actualSections[1] -eq "utilities")
Assert-Audit "Root section order matches exact specification: [footer, utilities]" $orderMatch "Got: $($actualSections -join ', ')"

Assert-Audit "Root contains section 'footer'" ($parsed.sections.footer -ne $null) "footer section missing"
Assert-Audit "Root contains section 'utilities'" ($parsed.sections.utilities -ne $null) "utilities section missing"

# ------------------------------------------------------------------------------
# 3. Footer Section Deep Inspection
# ------------------------------------------------------------------------------
Write-Host "`n--- 3. Footer Section Deep Inspection ---" -ForegroundColor Yellow

$footer = $parsed.sections.footer
Assert-Audit "Footer section type is 'footer'" ($footer.type -eq "footer") "Got '$($footer.type)'"
Assert-Audit "Footer background_color is '{{ settings.color_palette.color2 }}' (Soft Beige)" ($footer.settings.background_color -eq "{{ settings.color_palette.color2 }}") "Got '$($footer.settings.background_color)'"
Assert-Audit "Footer section_width is 'page-width'" ($footer.settings.section_width -eq "page-width") "Got '$($footer.settings.section_width)'"
Assert-Audit "Footer gap is 40px" ($footer.settings.gap -eq 40) "Got '$($footer.settings.gap)'"

$expectedFooterBlocks = @("group_newsletter", "menu_shop", "menu_care", "payment_icons")
$actualFooterBlocks = $footer.block_order
$footerBlocksMatch = ($actualFooterBlocks.Count -eq 4) -and 
                     ($actualFooterBlocks[0] -eq "group_newsletter") -and 
                     ($actualFooterBlocks[1] -eq "menu_shop") -and 
                     ($actualFooterBlocks[2] -eq "menu_care") -and 
                     ($actualFooterBlocks[3] -eq "payment_icons")
Assert-Audit "Footer block order matches exact 4-column architecture" $footerBlocksMatch "Got: $($actualFooterBlocks -join ', ')"

# Newsletter Group
$gNews = $footer.blocks.group_newsletter
Assert-Audit "group_newsletter type is 'group'" ($gNews.type -eq "group") "Got '$($gNews.type)'"
Assert-Audit "group_newsletter content_direction is 'column'" ($gNews.settings.content_direction -eq "column") "Got '$($gNews.settings.content_direction)'"
Assert-Audit "group_newsletter vertical_on_mobile is true" ($gNews.settings.vertical_on_mobile -eq $true) "Got '$($gNews.settings.vertical_on_mobile)'"

# Newsletter sub-blocks
$expectedNewsBlocks = @("text_heading", "text_subcopy", "email_signup")
$actualNewsBlocks = $gNews.block_order
$newsBlocksMatch = ($actualNewsBlocks.Count -eq 3) -and 
                   ($actualNewsBlocks[0] -eq "text_heading") -and 
                   ($actualNewsBlocks[1] -eq "text_subcopy") -and 
                   ($actualNewsBlocks[2] -eq "email_signup")
Assert-Audit "group_newsletter block order is [text_heading, text_subcopy, email_signup]" $newsBlocksMatch "Got: $($actualNewsBlocks -join ', ')"

# Heading
$heading = $gNews.blocks.text_heading
Assert-Audit "text_heading type is 'text'" ($heading.type -eq "text") "Got '$($heading.type)'"
Assert-Audit "text_heading contains 'Join the HERAVYN Movement'" ($heading.settings.text -eq "<h3>Join the HERAVYN Movement</h3>") "Got '$($heading.settings.text)'"
Assert-Audit "text_heading uses type_preset 'h3'" ($heading.settings.type_preset -eq "h3") "Got '$($heading.settings.type_preset)'"
Assert-Audit "text_heading uses font 'var(--font-heading--family)'" ($heading.settings.font -eq "var(--font-heading--family)") "Got '$($heading.settings.font)'"

# Subcopy
$subcopy = $gNews.blocks.text_subcopy
Assert-Audit "text_subcopy type is 'text'" ($subcopy.type -eq "text") "Got '$($subcopy.type)'"
Assert-Audit "text_subcopy features brand ethos and STRONGER YOU" ($subcopy.settings.text -match "STRONGER YOU") "Got '$($subcopy.settings.text)'"
Assert-Audit "text_subcopy uses type_preset 'rte'" ($subcopy.settings.type_preset -eq "rte") "Got '$($subcopy.settings.type_preset)'"

# Email Signup
$signup = $gNews.blocks.email_signup
Assert-Audit "email_signup type is 'email-signup'" ($signup.type -eq "email-signup") "Got '$($signup.type)'"
Assert-Audit "email_signup border_radius is 100 (pill shape)" ($signup.settings.border_radius -eq 100) "Got '$($signup.settings.border_radius)'"
Assert-Audit "email_signup input_style is 'custom'" ($signup.settings.input_style -eq "custom") "Got '$($signup.settings.input_style)'"
Assert-Audit "email_signup input_background_color is '{{ settings.color_palette.background }}' (Warm Ivory)" ($signup.settings.input_background_color -eq "{{ settings.color_palette.background }}") "Got '$($signup.settings.input_background_color)'"
Assert-Audit "email_signup input_border_color is '{{ settings.color_palette.color3 }}' (White)" ($signup.settings.input_border_color -eq "{{ settings.color_palette.color3 }}") "Got '$($signup.settings.input_border_color)'"
Assert-Audit "email_signup style_class is 'button-custom'" ($signup.settings.style_class -eq "button-custom") "Got '$($signup.settings.style_class)'"
Assert-Audit "email_signup custom_button_background is '{{ settings.color_palette.color1 }}' (Dusty Rose)" ($signup.settings.custom_button_background -eq "{{ settings.color_palette.color1 }}") "Got '$($signup.settings.custom_button_background)'"
Assert-Audit "email_signup custom_button_text is '#FFFFFF' (White)" ($signup.settings.custom_button_text -eq "#FFFFFF") "Got '$($signup.settings.custom_button_text)'"
Assert-Audit "email_signup custom_button_border is '{{ settings.color_palette.color1 }}' (Dusty Rose)" ($signup.settings.custom_button_border -eq "{{ settings.color_palette.color1 }}") "Got '$($signup.settings.custom_button_border)'"
Assert-Audit "email_signup label is 'Subscribe'" ($signup.settings.label -eq "Subscribe") "Got '$($signup.settings.label)'"
Assert-Audit "email_signup integrated_button is false" ($signup.settings.integrated_button -eq $false) "Got '$($signup.settings.integrated_button)'"

# Menus
$menuShop = $footer.blocks.menu_shop
Assert-Audit "menu_shop type is 'menu'" ($menuShop.type -eq "menu") "Got '$($menuShop.type)'"
Assert-Audit "menu_shop heading is 'Shop'" ($menuShop.settings.heading -eq "Shop") "Got '$($menuShop.settings.heading)'"
Assert-Audit "menu_shop menu handle is 'main-menu'" ($menuShop.settings.menu -eq "main-menu") "Got '$($menuShop.settings.menu)'"
Assert-Audit "menu_shop heading_preset is 'h6'" ($menuShop.settings.heading_preset -eq "h6") "Got '$($menuShop.settings.heading_preset)'"

$menuCare = $footer.blocks.menu_care
Assert-Audit "menu_care type is 'menu'" ($menuCare.type -eq "menu") "Got '$($menuCare.type)'"
Assert-Audit "menu_care heading is 'Customer Care'" ($menuCare.settings.heading -eq "Customer Care") "Got '$($menuCare.settings.heading)'"
Assert-Audit "menu_care menu handle is 'footer'" ($menuCare.settings.menu -eq "footer") "Got '$($menuCare.settings.menu)'"
Assert-Audit "menu_care heading_preset is 'h6'" ($menuCare.settings.heading_preset -eq "h6") "Got '$($menuCare.settings.heading_preset)'"

# Payment Icons
$payIcons = $footer.blocks.payment_icons
Assert-Audit "payment_icons type is 'payment-icons'" ($payIcons.type -eq "payment-icons") "Got '$($payIcons.type)'"
Assert-Audit "payment_icons horizontal_alignment is 'flex-start'" ($payIcons.settings.horizontal_alignment -eq "flex-start") "Got '$($payIcons.settings.horizontal_alignment)'"
Assert-Audit "payment_icons gap is 10" ($payIcons.settings.gap -eq 10) "Got '$($payIcons.settings.gap)'"

# ------------------------------------------------------------------------------
# 4. Utilities Section Deep Inspection
# ------------------------------------------------------------------------------
Write-Host "`n--- 4. Utilities Section Deep Inspection ---" -ForegroundColor Yellow

$util = $parsed.sections.utilities
Assert-Audit "utilities type is 'footer-utilities'" ($util.type -eq "footer-utilities") "Got '$($util.type)'"
Assert-Audit "utilities background_color is '{{ settings.color_palette.color2 }}' (Soft Beige)" ($util.settings.background_color -eq "{{ settings.color_palette.color2 }}") "Got '$($util.settings.background_color)'"
Assert-Audit "utilities divider_thickness is 1px" ($util.settings.divider_thickness -eq 1) "Got '$($util.settings.divider_thickness)'"
Assert-Audit "utilities divider_color is '{{ settings.color_palette.color3 }}' (White)" ($util.settings.divider_color -eq "{{ settings.color_palette.color3 }}") "Got '$($util.settings.divider_color)'"

$expectedUtilBlocks = @("copyright", "policy_list", "social_icons")
$actualUtilBlocks = $util.block_order
$utilBlocksMatch = ($actualUtilBlocks.Count -eq 3) -and 
                   ($actualUtilBlocks[0] -eq "copyright") -and 
                   ($actualUtilBlocks[1] -eq "policy_list") -and 
                   ($actualUtilBlocks[2] -eq "social_icons")
Assert-Audit "utilities block order matches [copyright, policy_list, social_icons] for 3-col grid layout" $utilBlocksMatch "Got: $($actualUtilBlocks -join ', ')"

# Copyright
$copyright = $util.blocks.copyright
Assert-Audit "copyright type is 'footer-copyright'" ($copyright.type -eq "footer-copyright") "Got '$($copyright.type)'"
Assert-Audit "copyright show_powered_by is false (Shopify branding suppressed per R4)" ($copyright.settings.show_powered_by -eq $false) "Got '$($copyright.settings.show_powered_by)'"
Assert-Audit "copyright font_size is '0.75rem'" ($copyright.settings.font_size -eq "0.75rem") "Got '$($copyright.settings.font_size)'"

# Policy list
$policy = $util.blocks.policy_list
Assert-Audit "policy_list type is 'footer-policy-list'" ($policy.type -eq "footer-policy-list") "Got '$($policy.type)'"
Assert-Audit "policy_list font_size is '0.75rem'" ($policy.settings.font_size -eq "0.75rem") "Got '$($policy.settings.font_size)'"

# Social links
$social = $util.blocks.social_icons
Assert-Audit "social_icons type is 'social-links'" ($social.type -eq "social-links") "Got '$($social.type)'"
Assert-Audit "social_icons instagram_url is 'https://www.instagram.com/heravyn'" ($social.settings.instagram_url -eq "https://www.instagram.com/heravyn") "Got '$($social.settings.instagram_url)'"
Assert-Audit "social_icons tiktok_url is 'https://www.tiktok.com/@heravyn'" ($social.settings.tiktok_url -eq "https://www.tiktok.com/@heravyn") "Got '$($social.settings.tiktok_url)'"
Assert-Audit "social_icons youtube_url is 'https://www.youtube.com/@heravyn'" ($social.settings.youtube_url -eq "https://www.youtube.com/@heravyn") "Got '$($social.settings.youtube_url)'"
Assert-Audit "social_icons facebook_url is 'https://www.facebook.com/heravyn'" ($social.settings.facebook_url -eq "https://www.facebook.com/heravyn") "Got '$($social.settings.facebook_url)'"

# ------------------------------------------------------------------------------
# 5. Native Horizon Liquid Schema & Block Compatibility Check
# ------------------------------------------------------------------------------
Write-Host "`n--- 5. Native Horizon Liquid Schema & Block Compatibility ---" -ForegroundColor Yellow

# Footer Liquid schema check
$footerLiquid = Get-Content (Join-Path $ProjectRoot "sections\footer.liquid") -Raw
$footerSchemaMatch = [regex]::Match($footerLiquid, '\{%\s*schema\s*%\}(.*?)\{%\s*endschema\s*%\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Assert-Audit "sections/footer.liquid schema extracted" ($footerSchemaMatch.Success) "Could not find schema in footer.liquid"

if ($footerSchemaMatch.Success) {
    $footerSchema = $footerSchemaMatch.Groups[1].Value | ConvertFrom-Json
    $allowedBlocks = $footerSchema.blocks | ForEach-Object { $_.type }
    Assert-Audit "footer schema allows 'group' block" ($allowedBlocks -contains "group") ""
    Assert-Audit "footer schema allows 'menu' block" ($allowedBlocks -contains "menu") ""
    Assert-Audit "footer schema allows 'payment-icons' block" ($allowedBlocks -contains "payment-icons") ""
    Assert-Audit "footer schema allows 'email-signup' block" ($allowedBlocks -contains "email-signup") ""
    Assert-Audit "footer schema allows 'text' block" ($allowedBlocks -contains "text") ""
}

# Footer-utilities Liquid schema check
$utilLiquid = Get-Content (Join-Path $ProjectRoot "sections\footer-utilities.liquid") -Raw
$utilSchemaMatch = [regex]::Match($utilLiquid, '\{%\s*schema\s*%\}(.*?)\{%\s*endschema\s*%\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Assert-Audit "sections/footer-utilities.liquid schema extracted" ($utilSchemaMatch.Success) "Could not find schema in footer-utilities.liquid"

if ($utilSchemaMatch.Success) {
    $utilSchema = $utilSchemaMatch.Groups[1].Value | ConvertFrom-Json
    $allowedUtilBlocks = $utilSchema.blocks | ForEach-Object { $_.type }
    Assert-Audit "utilities schema allows 'footer-copyright' block" ($allowedUtilBlocks -contains "footer-copyright") ""
    Assert-Audit "utilities schema allows 'footer-policy-list' block" ($allowedUtilBlocks -contains "footer-policy-list") ""
    Assert-Audit "utilities schema allows 'social-links' block" ($allowedUtilBlocks -contains "social-links") ""
    Assert-Audit "utilities blocks count (3) <= max_blocks ($($utilSchema.max_blocks))" (3 -le $utilSchema.max_blocks) ""
}

# ------------------------------------------------------------------------------
# 6. Dynamic Color Token Resolution with config/settings_data.json
# ------------------------------------------------------------------------------
Write-Host "`n--- 6. Dynamic Color Token Resolution ---" -ForegroundColor Yellow

$settingsRaw = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "config\settings_data.json"), [System.Text.Encoding]::UTF8)
$settingsClean = [regex]::Replace($settingsRaw, '^\s*/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline).Trim()
$settingsParsed = $settingsClean | ConvertFrom-Json
$palette = $settingsParsed.current.color_palette

Assert-Audit "settings_data.json contains color_palette" ($palette -ne $null) ""
Assert-Audit "color_palette.background resolves to Warm Ivory (#FAF7F3)" ($palette.background -eq "#FAF7F3") "Got '$($palette.background)'"
Assert-Audit "color_palette.foreground resolves to Deep Charcoal (#252525)" ($palette.foreground -eq "#252525") "Got '$($palette.foreground)'"
Assert-Audit "color_palette.color1 resolves to Dusty Rose (#B87570)" ($palette.color1 -eq "#B87570") "Got '$($palette.color1)'"
Assert-Audit "color_palette.color2 resolves to Soft Beige (#E9DED5)" ($palette.color2 -eq "#E9DED5") "Got '$($palette.color2)'"
Assert-Audit "color_palette.color3 resolves to White (#FFFFFF)" ($palette.color3 -eq "#FFFFFF") "Got '$($palette.color3)'"

# ------------------------------------------------------------------------------
# 7. Git & Architecture Forensics
# ------------------------------------------------------------------------------
Write-Host "`n--- 7. Git & Architecture Forensics ---" -ForegroundColor Yellow

# Verify no .liquid files modified in git
$gitDiffOutput = git diff --name-only
$liquidModified = ($gitDiffOutput -split '\r?\n') | Where-Object { $_ -like "*.liquid" }
Assert-Audit "Zero .liquid files modified in git diff" ($liquidModified.Count -eq 0) "Modified liquid files: $($liquidModified -join ', ')"

# Verify theme.liquid layout hooks are untouched
$themeLiquid = Get-Content (Join-Path $ProjectRoot "layout\theme.liquid") -Raw
Assert-Audit "layout/theme.liquid contains 'content_for_header'" ($themeLiquid -match 'content_for_header') "Missing content_for_header hook"
Assert-Audit "layout/theme.liquid contains 'content_for_layout'" ($themeLiquid -match 'content_for_layout') "Missing content_for_layout hook"
Assert-Audit "layout/theme.liquid contains sections 'footer-group'" ($themeLiquid -match "sections\s+'footer-group'") "Missing footer-group render hook"
Assert-Audit "layout/theme.liquid contains sections 'header-group'" ($themeLiquid -match "sections\s+'header-group'") "Missing header-group render hook"

# Verify no pre-populated log files or test output artifacts
$logFiles = Get-ChildItem -Path $ProjectRoot -Recurse -Include *.log -File | Where-Object { $_.FullName -notmatch '\.git' }
Assert-Audit "Zero pre-populated .log files in repository" ($logFiles.Count -eq 0) "Found: $($logFiles.FullName -join ', ')"

# ------------------------------------------------------------------------------
# Audit Summary
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "AUDIT SUITE SUMMARY" -ForegroundColor Cyan
Write-Host "Total checks: $TotalChecks | Passed: $PassedChecks | Failed: $FailedChecks" -ForegroundColor Cyan
if ($FailedChecks -eq 0) {
    Write-Host "VERDICT: CLEAN - ZERO INTEGRITY VIOLATIONS" -ForegroundColor Green
} else {
    Write-Host "VERDICT: INTEGRITY VIOLATION ($FailedChecks failures)" -ForegroundColor Red
    foreach ($v in $Violations) {
        Write-Host "  - $v" -ForegroundColor Red
    }
}
Write-Host "======================================================================" -ForegroundColor Cyan

if ($FailedChecks -gt 0) {
    exit 1
} else {
    exit 0
}
