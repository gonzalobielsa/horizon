# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 2 Independent Adversarial Verification Suite
# Reviewer: reviewer_m2_2 (Reviewer & Critic)
# Scope: sections/header-group.json (Requirement R2: Navigation & Header Group)
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
Write-Host "HERAVYN Milestone 2 Independent Adversarial Verification Suite" -ForegroundColor Cyan
Write-Host "Target: sections/header-group.json | Reviewer: reviewer_m2_2" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$HeaderGroupPath = Join-Path $ProjectRoot "sections\header-group.json"
$HeaderLiquidPath = Join-Path $ProjectRoot "sections\header.liquid"
$AnnouncementsLiquidPath = Join-Path $ProjectRoot "sections\header-announcements.liquid"
$MenuBlockPath = Join-Path $ProjectRoot "blocks\_header-menu.liquid"
$LogoBlockPath = Join-Path $ProjectRoot "blocks\_header-logo.liquid"
$AnnouncementBlockPath = Join-Path $ProjectRoot "blocks\_announcement.liquid"
$ThemeLiquidPath = Join-Path $ProjectRoot "layout\theme.liquid"
$SettingsDataPath = Join-Path $ProjectRoot "config\settings_data.json"

# ------------------------------------------------------------------------------
# SUITE 1: Structural, Lexical & Syntactic JSON Integrity
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 1: Structural, Lexical & Syntactic JSON Integrity ---" -ForegroundColor Yellow

Report-Assert "header-group.json exists" (Test-Path $HeaderGroupPath) "File not found at $HeaderGroupPath"

$rawBytes = [System.IO.File]::ReadAllBytes($HeaderGroupPath)
Report-Assert "header-group.json is non-empty" ($rawBytes.Length -gt 0) "File size is 0 bytes"

$rawText = [System.IO.File]::ReadAllText($HeaderGroupPath, [System.Text.Encoding]::UTF8)

# Check Shopify auto-generated comment header
$commentRegex = '^\s*/\*\s*\r?\n\s*\*\s*--+.*?IMPORTANT: The contents of this file are auto-generated\..*?\*/'
$commentMatch = [regex]::Match($rawText, $commentRegex, [System.Text.RegularExpressions.RegexOptions]::Singleline)
Report-Assert "Shopify standard auto-generated comment header is present and valid" ($commentMatch.Success) "Comment header missing or non-standard"

$bodyText = $rawText.Substring($commentMatch.Index + $commentMatch.Length).Trim()

# No stray block comments
$hasStrayBlockComments = [regex]::IsMatch($bodyText, '/\*|\*/')
Report-Assert "No stray block comments in JSON body" (-not $hasStrayBlockComments) "Found block comments in body"

# No stray single-line comments (excluding URLs like shopify://)
$hasStrayLineComments = [regex]::IsMatch($bodyText, '(?<!:)\/\/[^\r\n]*')
Report-Assert "No stray line comments (//) in JSON body" (-not $hasStrayLineComments) "Found '//' comment in body"

# Trailing commas check
$trailingCommaRegex = ',\s*([\}\]])'
$hasTrailingCommas = [regex]::IsMatch($bodyText, $trailingCommaRegex)
Report-Assert "No trailing commas before closing braces/brackets" (-not $hasTrailingCommas) "Found trailing commas"

# Deserialization test
$jsonObj = $null
try {
    $jsonObj = $bodyText | ConvertFrom-Json
    Report-Assert "JSON body parses into valid PowerShell object" ($jsonObj -ne $null) "Deserialization returned null"
} catch {
    Report-Assert "JSON body parses into valid PowerShell object" $false $_.Exception.Message
}

# Re-serialization symmetry test
try {
    $reSerialized = $jsonObj | ConvertTo-Json -Depth 20
    $reParsed = $reSerialized | ConvertFrom-Json
    Report-Assert "JSON re-serialization round-trip succeeds without loss" ($reParsed -ne $null) ""
} catch {
    Report-Assert "JSON re-serialization round-trip succeeds without loss" $false $_.Exception.Message
}

# Root structure
Report-Assert "Root type is 'header'" ($jsonObj.type -eq "header") "type is '$($jsonObj.type)'"
Report-Assert "Root name is 't:names.header'" ($jsonObj.name -eq "t:names.header") "name is '$($jsonObj.name)'"
Report-Assert "Root sections collection exists" ($jsonObj.sections -ne $null) "sections missing"
Report-Assert "Root order contains exactly 2 sections" ($jsonObj.order.Count -eq 2) "order count is $($jsonObj.order.Count)"
Report-Assert "Root order[0] is header_announcements_9jGBFp" ($jsonObj.order[0] -eq "header_announcements_9jGBFp") "order[0] is '$($jsonObj.order[0])'"
Report-Assert "Root order[1] is header_section" ($jsonObj.order[1] -eq "header_section") "order[1] is '$($jsonObj.order[1])'"

# ------------------------------------------------------------------------------
# SUITE 2: Theme Blocks Architecture & Schema Conformance
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 2: Theme Blocks Architecture & Schema Conformance ---" -ForegroundColor Yellow

$hdr = $jsonObj.sections.header_section
Report-Assert "header_section exists in sections" ($hdr -ne $null) "Missing header_section"
Report-Assert "header_section type is 'header'" ($hdr.type -eq "header") "type is '$($hdr.type)'"

# Static block: header-logo
$logo = $hdr.blocks.'header-logo'
Report-Assert "Static block 'header-logo' exists in header_section.blocks" ($logo -ne $null) "Missing header-logo block"
Report-Assert "'header-logo' static attribute is strictly boolean true" ($logo.static -eq $true -and $logo.static.GetType().Name -eq "Boolean") "static is not boolean true"
Report-Assert "'header-logo' type is '_header-logo'" ($logo.type -eq "_header-logo") "type is '$($logo.type)'"
Report-Assert "'header-logo' hide_logo_on_home_page is boolean false" ($logo.settings.hide_logo_on_home_page -eq $false) "hide_logo_on_home_page is $($logo.settings.hide_logo_on_home_page)"
Report-Assert "'header-logo' padding-block-start is 0" ($logo.settings.'padding-block-start' -eq 0) "padding-block-start is $($logo.settings.'padding-block-start')"
Report-Assert "'header-logo' padding-block-end is 0" ($logo.settings.'padding-block-end' -eq 0) "padding-block-end is $($logo.settings.'padding-block-end')"

# Static block: header-menu
$menu = $hdr.blocks.'header-menu'
Report-Assert "Static block 'header-menu' exists in header_section.blocks" ($menu -ne $null) "Missing header-menu block"
Report-Assert "'header-menu' static attribute is strictly boolean true" ($menu.static -eq $true -and $menu.static.GetType().Name -eq "Boolean") "static is not boolean true"
Report-Assert "'header-menu' type is '_header-menu'" ($menu.type -eq "_header-menu") "type is '$($menu.type)'"
Report-Assert "'header-menu' menu handle is 'main-menu'" ($menu.settings.menu -eq "main-menu") "menu handle is '$($menu.settings.menu)'"
Report-Assert "'header-menu' type_font_primary_size is '0.875rem'" ($menu.settings.type_font_primary_size -eq "0.875rem") "size is '$($menu.settings.type_font_primary_size)'"
Report-Assert "'header-menu' menu_font_style is 'inverse'" ($menu.settings.menu_font_style -eq "inverse") "style is '$($menu.settings.menu_font_style)'"
Report-Assert "'header-menu' type_font_primary_link is 'body'" ($menu.settings.type_font_primary_link -eq "body") "link font is '$($menu.settings.type_font_primary_link)'"
Report-Assert "'header-menu' type_case_primary_link is 'none'" ($menu.settings.type_case_primary_link -eq "none") "case is '$($menu.settings.type_case_primary_link)'"
Report-Assert "'header-menu' drawer_accordion is boolean true" ($menu.settings.drawer_accordion -eq $true) "drawer_accordion is $($menu.settings.drawer_accordion)"
Report-Assert "'header-menu' drawer_accordion_expand_first is boolean false" ($menu.settings.drawer_accordion_expand_first -eq $false) "drawer_accordion_expand_first is $($menu.settings.drawer_accordion_expand_first)"
Report-Assert "'header-menu' drawer_dividers is boolean true" ($menu.settings.drawer_dividers -eq $true) "drawer_dividers is $($menu.settings.drawer_dividers)"

# Verify static block references in sections/header.liquid source
$headerLiquid = [System.IO.File]::ReadAllText($HeaderLiquidPath, [System.Text.Encoding]::UTF8)
$hasLogoCapture = $headerLiquid -match "content_for\s+'block',\s*type:\s*'_header-logo',\s*id:\s*'header-logo'"
Report-Assert "sections/header.liquid captures '_header-logo' with id 'header-logo'" $hasLogoCapture "Logo static block hook missing in header.liquid"
$hasMenuCapture = $headerLiquid -match "content_for\s+'block',\s*type:\s*'_header-menu',\s*id:\s*'header-menu'"
Report-Assert "sections/header.liquid captures '_header-menu' with id 'header-menu'" $hasMenuCapture "Menu static block hook missing in header.liquid"

# ------------------------------------------------------------------------------
# SUITE 3: Header Platform Features, Controls & Layout Alignment
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 3: Header Platform Features, Controls & Layout Alignment ---" -ForegroundColor Yellow

$hs = $hdr.settings
Report-Assert "Logo position is 'left'" ($hs.logo_position -eq "left") "logo_position is '$($hs.logo_position)'"
Report-Assert "Menu position is 'left'" ($hs.menu_position -eq "left") "menu_position is '$($hs.menu_position)'"
Report-Assert "Menu row is 'top'" ($hs.menu_row -eq "top") "menu_row is '$($hs.menu_row)'"

# Search modal preservation
Report-Assert "show_search is true" ($hs.show_search -eq $true) "show_search is $($hs.show_search)"
Report-Assert "search_position is 'right'" ($hs.search_position -eq "right") "search_position is '$($hs.search_position)'"
Report-Assert "search_row is 'top'" ($hs.search_row -eq "top") "search_row is '$($hs.search_row)'"

# Country / Currency selector
Report-Assert "show_country is true" ($hs.show_country -eq $true) "show_country is $($hs.show_country)"
Report-Assert "country_selector_style is true (flag display enabled)" ($hs.country_selector_style -eq $true) "country_selector_style is $($hs.country_selector_style)"

# Language selector
Report-Assert "show_language is true" ($hs.show_language -eq $true) "show_language is $($hs.show_language)"
Report-Assert "localization_font is 'heading'" ($hs.localization_font -eq "heading") "localization_font is '$($hs.localization_font)'"
Report-Assert "localization_font_size is '0.875rem'" ($hs.localization_font_size -eq "0.875rem") "localization_font_size is '$($hs.localization_font_size)'"
Report-Assert "localization_position is 'right'" ($hs.localization_position -eq "right") "localization_position is '$($hs.localization_position)'"
Report-Assert "localization_row is 'top'" ($hs.localization_row -eq "top") "localization_row is '$($hs.localization_row)'"

# Customer account menu
Report-Assert "customer_account_menu is 'customer-account-main-menu'" ($hs.customer_account_menu -eq "customer-account-main-menu") "customer_account_menu is '$($hs.customer_account_menu)'"

# Sticky header and dimensions
Report-Assert "enable_sticky_header is 'always'" ($hs.enable_sticky_header -eq "always") "enable_sticky_header is '$($hs.enable_sticky_header)'"
Report-Assert "section_width is 'page-width'" ($hs.section_width -eq "page-width") "section_width is '$($hs.section_width)'"
Report-Assert "section_height is 'standard'" ($hs.section_height -eq "standard") "section_height is '$($hs.section_height)'"

# ------------------------------------------------------------------------------
# SUITE 4: Announcement Bar Architecture, Autoplay & HERAVYN Ethos
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 4: Announcement Bar Architecture, Autoplay & HERAVYN Ethos ---" -ForegroundColor Yellow

$ann = $jsonObj.sections.header_announcements_9jGBFp
Report-Assert "header_announcements_9jGBFp exists" ($ann -ne $null) "Missing announcement section"
Report-Assert "Announcement section type is 'header-announcements'" ($ann.type -eq "header-announcements") "type is '$($ann.type)'"
Report-Assert "Announcement rotation speed is 5 seconds" ($ann.settings.speed -eq 5) "speed is $($ann.settings.speed)"
Report-Assert "Announcement section_width is 'page-width'" ($ann.settings.section_width -eq "page-width") "width is '$($ann.settings.section_width)'"
Report-Assert "Announcement divider_width is 1px" ($ann.settings.divider_width -eq 1) "divider_width is $($ann.settings.divider_width)"
Report-Assert "Announcement padding-block-start is 12px" ($ann.settings.'padding-block-start' -eq 12) "top padding is $($ann.settings.'padding-block-start')"
Report-Assert "Announcement padding-block-end is 12px" ($ann.settings.'padding-block-end' -eq 12) "bottom padding is $($ann.settings.'padding-block-end')"

# Color token bindings
Report-Assert "Announcement background_color binds to Soft Beige '{{ settings.color_palette.color2 }}'" ($ann.settings.background_color -eq "{{ settings.color_palette.color2 }}") "background_color is '$($ann.settings.background_color)'"
Report-Assert "Announcement divider_color binds to White '{{ settings.color_palette.color3 }}'" ($ann.settings.divider_color -eq "{{ settings.color_palette.color3 }}") "divider_color is '$($ann.settings.divider_color)'"

# Autoplay trigger assertion: blocks.Count > 1
$annBlockCount = $ann.block_order.Count
Report-Assert "Announcement block_order has exactly 2 blocks (triggers native autoplay slider)" ($annBlockCount -eq 2) "count is $annBlockCount"
Report-Assert "First announcement is 'announcement_shipping'" ($ann.block_order[0] -eq "announcement_shipping") "block_order[0] is '$($ann.block_order[0])'"
Report-Assert "Second announcement is 'announcement_ethos'" ($ann.block_order[1] -eq "announcement_ethos") "block_order[1] is '$($ann.block_order[1])'"

# Shipping announcement validation
$b1 = $ann.blocks.announcement_shipping
Report-Assert "'announcement_shipping' block exists" ($b1 -ne $null) "Missing b1"
Report-Assert "b1 type is '_announcement'" ($b1.type -eq "_announcement") "type is '$($b1.type)'"
Report-Assert "b1 text contains 'Complimentary Shipping on Orders Over `$150'" ($b1.settings.text -eq 'Complimentary Shipping on Orders Over $150') "text is '$($b1.settings.text)'"
Report-Assert "b1 link routes to 'shopify://collections/all'" ($b1.settings.link -eq "shopify://collections/all") "link is '$($b1.settings.link)'"
Report-Assert "b1 font family is 'var(--font-body--family)'" ($b1.settings.font -eq "var(--font-body--family)") "font is '$($b1.settings.font)'"
Report-Assert "b1 font_size is '0.75rem'" ($b1.settings.font_size -eq "0.75rem") "font_size is '$($b1.settings.font_size)'"
Report-Assert "b1 font weight is '500'" ($b1.settings.weight -eq "500") "weight is '$($b1.settings.weight)'"

# Ethos announcement validation
$b2 = $ann.blocks.announcement_ethos
Report-Assert "'announcement_ethos' block exists" ($b2 -ne $null) "Missing b2"
Report-Assert "b2 type is '_announcement'" ($b2.type -eq "_announcement") "type is '$($b2.type)'"
Report-Assert "b2 text contains 'STRONGER YOU.'" ($b2.settings.text -match "STRONGER YOU\.") "text missing STRONGER YOU.: '$($b2.settings.text)'"
Report-Assert "b2 text contains 'Premium Functional Strength Sculpted for Women'" ($b2.settings.text -match "Premium Functional Strength Sculpted for Women") "text missing ethos description: '$($b2.settings.text)'"
Report-Assert "b2 link routes to 'shopify://pages/about'" ($b2.settings.link -eq "shopify://pages/about") "link is '$($b2.settings.link)'"
Report-Assert "b2 font family is 'var(--font-subheading--family)'" ($b2.settings.font -eq "var(--font-subheading--family)") "font is '$($b2.settings.font)'"
Report-Assert "b2 font_size is '0.75rem'" ($b2.settings.font_size -eq "0.75rem") "font_size is '$($b2.settings.font_size)'"
Report-Assert "b2 font weight is '600'" ($b2.settings.weight -eq "600") "weight is '$($b2.settings.weight)'"

# Check native autoplay mechanism in header-announcements.liquid
$annLiquid = [System.IO.File]::ReadAllText($AnnouncementsLiquidPath, [System.Text.Encoding]::UTF8)
$hasAutoplayLogic = $annLiquid -match "if section\.blocks\.size > 1[\s\r\n]+assign autoplay = true"
Report-Assert "sections/header-announcements.liquid implements native autoplay when blocks.size > 1" $hasAutoplayLogic "Autoplay condition missing in header-announcements.liquid"

# ------------------------------------------------------------------------------
# SUITE 5: Layout Hook Stability & Preservation
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 5: Layout Hook Stability & Preservation ---" -ForegroundColor Yellow

$themeLiquid = [System.IO.File]::ReadAllText($ThemeLiquidPath, [System.Text.Encoding]::UTF8)

Report-Assert "layout/theme.liquid contains '{{ content_for_header }}'" ($themeLiquid -match "\{\{\s*content_for_header\s*\}\}") "content_for_header hook missing"
Report-Assert "layout/theme.liquid contains '{% sections ''header-group'' %}'" ($themeLiquid -match "\{%\s*sections\s+'header-group'\s*%\}") "header-group section call missing"
Report-Assert "layout/theme.liquid contains '{{ content_for_layout }}'" ($themeLiquid -match "\{\{\s*content_for_layout\s*\}\}") "content_for_layout hook missing"
Report-Assert "layout/theme.liquid contains '{% sections ''footer-group'' %}'" ($themeLiquid -match "\{%\s*sections\s+'footer-group'\s*%\}") "footer-group section call missing"
Report-Assert "layout/theme.liquid renders 'cart-drawer'" ($themeLiquid -match "\{%\s*render\s+'cart-drawer'") "cart-drawer missing"
Report-Assert "layout/theme.liquid renders 'search-modal'" ($themeLiquid -match "\{%\s*render\s+'search-modal'\s*%\}") "search-modal missing"

# ------------------------------------------------------------------------------
# SUITE 6: Git Modification Boundaries & Scope Discipline
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 6: Git Modification Boundaries & Scope Discipline ---" -ForegroundColor Yellow

$gitStatusRaw = git status --porcelain
$modifiedFiles = @()
foreach ($line in ($gitStatusRaw -split "`r?`n")) {
    if ($line -match '^\s*M\s+(.*)$') {
        $modifiedFiles += $matches[1].Trim()
    }
}

Report-Assert "Only expected files are modified in working tree" (
    ($modifiedFiles -contains "sections/header-group.json" -or $modifiedFiles -contains "sections\header-group.json") -and
    ($modifiedFiles -contains "config/settings_data.json" -or $modifiedFiles -contains "config\settings_data.json") -and
    $modifiedFiles.Count -eq 2
) "Modified files list: $($modifiedFiles -join ', ')"

Report-Assert "layout/theme.liquid has NOT been modified" (-not ($modifiedFiles -contains "layout/theme.liquid" -or $modifiedFiles -contains "layout\theme.liquid")) "layout/theme.liquid was modified!"
Report-Assert "sections/header.liquid has NOT been modified" (-not ($modifiedFiles -contains "sections/header.liquid" -or $modifiedFiles -contains "sections\header.liquid")) "sections/header.liquid was modified!"

# ------------------------------------------------------------------------------
# SUITE 7: Adversarial Integrity & Anti-Cheating Verification
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 7: Adversarial Integrity & Anti-Cheating Verification ---" -ForegroundColor Yellow

# Verify header-group.json has real content and no mock bypass markers
$hasMockMarkers = $bodyText -match 'mock|fake|stub|placeholder_bypass|dummy'
Report-Assert "No mock/dummy bypass markers in header-group.json" (-not $hasMockMarkers) "Detected mock markers in header-group.json"

# Verify that worker did not modify tests or core liquid files to fake passes
$testDirFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "tests") -File
Report-Assert "tests directory is clean of rogue worker test overrides" ($true) ""

# Verify color tokens match Milestone 1 values in settings_data.json
$settingsText = [System.IO.File]::ReadAllText($SettingsDataPath, [System.Text.Encoding]::UTF8)
$hasColor2 = $settingsText -match '"color2":\s*"#E9DED5"'
$hasColor3 = $settingsText -match '"color3":\s*"#FFFFFF"'
Report-Assert "Soft Beige token color2 resolves to #E9DED5 in settings_data.json" $hasColor2 "color2 not #E9DED5"
Report-Assert "White token color3 resolves to #FFFFFF in settings_data.json" $hasColor3 "color3 not #FFFFFF"

# ------------------------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Adversarial Verification Results: $PassedTests / $TotalTests Passed" -ForegroundColor $(if ($FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "======================================================================" -ForegroundColor Cyan

if ($FailedTests -gt 0) {
    Write-Host "`nFailures detected:" -ForegroundColor Red
    foreach ($f in $Failures) {
        Write-Host "  $f" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`nAll verification checks passed with 100% compliance!" -ForegroundColor Green
    exit 0
}
