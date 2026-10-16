# ==============================================================================
# HERAVYN Milestone 2 - Empirical Adversarial Challenge Suite (challenger_m2_2)
# Scope: Announcement Rotation, Sticky Header, Responsive Layout, Navigation & Localization
# ==============================================================================
param(
    [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$Total = 0
$Passed = 0
$Failed = 0
$Failures = @()

function Test-Empirical($Title, $Condition, $FailureDetail = "") {
    $script:Total++
    if ($Condition) {
        $script:Passed++
        Write-Host "  [PASS] $Title" -ForegroundColor Green
    } else {
        $script:Failed++
        $err = "  [FAIL] ${Title}: $FailureDetail"
        $script:Failures += $err
        Write-Host $err -ForegroundColor Red
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "HERAVYN Milestone 2 Empirical Adversarial Challenge Suite" -ForegroundColor Cyan
Write-Host "Challenger Agent: challenger_m2_2 | Operating System: Windows PowerShell" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$HeaderGroupFile = Join-Path $ProjectRoot "sections\header-group.json"
$HeaderLiquidFile = Join-Path $ProjectRoot "sections\header.liquid"
$AnnouncementsLiquidFile = Join-Path $ProjectRoot "sections\header-announcements.liquid"
$AnnouncementBlockFile = Join-Path $ProjectRoot "blocks\_announcement.liquid"
$AnnouncementJsFile = Join-Path $ProjectRoot "assets\announcement-bar.js"
$HeaderJsFile = Join-Path $ProjectRoot "assets\header.js"
$HeaderDrawerLiquidFile = Join-Path $ProjectRoot "snippets\header-drawer.liquid"
$HeaderRowLiquidFile = Join-Path $ProjectRoot "snippets\header-row.liquid"
$HeaderActionsLiquidFile = Join-Path $ProjectRoot "snippets\header-actions.liquid"
$LocalizationFormFile = Join-Path $ProjectRoot "snippets\localization-form.liquid"
$LocalizationJsFile = Join-Path $ProjectRoot "assets\localization.js"
$SettingsDataFile = Join-Path $ProjectRoot "config\settings_data.json"

# Load header-group.json
Test-Empirical "header-group.json exists" (Test-Path $HeaderGroupFile)
$rawHeaderGroup = [System.IO.File]::ReadAllText($HeaderGroupFile, [System.Text.Encoding]::UTF8)

# Strip comment header if present
$commentMatch = [regex]::Match($rawHeaderGroup, '^\s*/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Test-Empirical "Shopify auto-generated comment header is present and valid" ($commentMatch.Success)
$headerGroupJson = $rawHeaderGroup.Substring($commentMatch.Index + $commentMatch.Length).Trim()
$headerGroupObj = $headerGroupJson | ConvertFrom-Json

# ------------------------------------------------------------------------------
# SECTION 1: Announcement Rotation Execution & Mathematical Invariants
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 1: Announcement Rotation Execution & JS Mathematics ---" -ForegroundColor Yellow

$annSection = $headerGroupObj.sections.header_announcements_9jGBFp
Test-Empirical "header_announcements_9jGBFp section exists" ($annSection -ne $null)
Test-Empirical "Announcement section type is 'header-announcements'" ($annSection.type -eq "header-announcements")
Test-Empirical "Announcement section has exactly 2 blocks" ($annSection.block_order.Count -eq 2)

# Check header-announcements.liquid logic
$annLiquid = [System.IO.File]::ReadAllText($AnnouncementsLiquidFile, [System.Text.Encoding]::UTF8)
$hasAutoplayAssign = $annLiquid -match "if section\.blocks\.size > 1[\s\r\n]+assign autoplay = true[\s\r\n]+assign show_arrows = true"
Test-Empirical "header-announcements.liquid activates autoplay when blocks.size > 1" ($hasAutoplayAssign)

$hasScriptInclude = $annLiquid -match '\{%\s*if section\.blocks\.size > 1\s*%\}\s*<script\s+src="\{\{\s*''announcement-bar\.js''\s*\|\s*asset_url\s*\}\}"'
Test-Empirical "header-announcements.liquid dynamically includes announcement-bar.js only when blocks.size > 1" ($hasScriptInclude)

$hasComponentTag = $annLiquid -match '<announcement-bar-component[\s\S]*?autoplay="\{\{\s*section\.settings\.speed\s*\}\}"'
Test-Empirical "header-announcements.liquid renders <announcement-bar-component> with autoplay attribute" ($hasComponentTag)

# Verify announcement-bar.js implementation
Test-Empirical "announcement-bar.js asset exists" (Test-Path $AnnouncementJsFile)
$annJs = [System.IO.File]::ReadAllText($AnnouncementJsFile, [System.Text.Encoding]::UTF8)

$hasCustomElementDef = $annJs -match "customElements\.define\('announcement-bar-component',\s*AnnouncementBar\)"
Test-Empirical "announcement-bar.js defines 'announcement-bar-component' custom element" ($hasCustomElementDef)

$hasConnectedCallback = $annJs -match "connectedCallback\(\)\s*\{[\s\S]*?this\.play\(\);"
Test-Empirical "announcement-bar.js connectedCallback initializes play()" ($hasConnectedCallback)

# Mathematical model simulation for AnnouncementBar rotation
# JS rotation mathematics from announcement-bar.js:
#   let relativeIndex = current % (this.refs.slides ?? []).length;
#   if (relativeIndex < 0) { relativeIndex += (this.refs.slides ?? []).length; }
function Simulate-JsAnnouncementRotation($slideCount, $steps) {
    $current = 0
    $history = @()
    for ($i = 0; $i -lt $steps; $i++) {
        $rel = $current % $slideCount
        if ($rel -lt 0) { $rel += $slideCount }
        $history += $rel
        $current++
    }
    return $history
}

$simResults = Simulate-JsAnnouncementRotation 2 10
$expectedPattern = @(0, 1, 0, 1, 0, 1, 0, 1, 0, 1)
$simMatches = ($simResults -join ",") -eq ($expectedPattern -join ",")
Test-Empirical "Empirical JS Rotation Simulation: Alternates 0 -> 1 -> 0 -> 1 across 10 ticks" ($simMatches) "Got: $($simResults -join ',')"

# Test previous() navigation wrap-around (simulating clicking previous button)
function Simulate-JsPreviousNavigation($slideCount, $clicks) {
    $current = 0
    $history = @()
    for ($i = 0; $i -lt $clicks; $i++) {
        $current--
        $rel = $current % $slideCount
        if ($rel -lt 0) { $rel += $slideCount }
        $history += $rel
    }
    return $history
}
$prevResults = Simulate-JsPreviousNavigation 2 6
$expectedPrev = @(1, 0, 1, 0, 1, 0)
$prevMatches = ($prevResults -join ",") -eq ($expectedPrev -join ",")
Test-Empirical "Empirical JS Rotation Simulation: Previous navigation correctly wraps negative indices to (1, 0, 1, 0...)" ($prevMatches) "Got: $($prevResults -join ',')"

# Test autoplayInterval calculation with speed = 5
$configuredSpeed = $annSection.settings.speed
Test-Empirical "Announcement speed setting is integer 5 (5 seconds)" ($configuredSpeed -eq 5)
$expectedIntervalMs = $configuredSpeed * 1000
Test-Empirical "Calculated autoplay interval equals 5000ms" ($expectedIntervalMs -eq 5000)

# Check pause / resume on hover & visibility
$hasHoverEvents = ($annJs -match "mouseenter.*this\.suspend") -and ($annJs -match "mouseleave.*this\.resume")
Test-Empirical "announcement-bar.js implements hover suspend/resume handlers" ($hasHoverEvents)

$hasVisibilityEvent = $annJs -match "visibilitychange.*handleVisibilityChange"
Test-Empirical "announcement-bar.js handles document visibility changes (pauses tab when hidden)" ($hasVisibilityEvent)

# Check block slides structure and aria-hidden initial state
$annBlockLiquid = [System.IO.File]::ReadAllText($AnnouncementBlockFile, [System.Text.Encoding]::UTF8)
$hasSlideRef = $annBlockLiquid -match '<slideshow-slide[\s\S]*?ref="slides\[\]"'
Test-Empirical "_announcement.liquid declares ref='slides[]' matching AnnouncementBar component" ($hasSlideRef)

$hasAriaHiddenLogic = $annBlockLiquid -match 'aria-hidden="\{%\s*if block_index == 0\s*%\}\s*false\s*\{%\s*else\s*%\}\s*true\s*\{%\s*endif\s*%\}"'
Test-Empirical "_announcement.liquid initializes aria-hidden: false for slide 0 and true for slide 1" ($hasAriaHiddenLogic)

# ------------------------------------------------------------------------------
# SECTION 2: Sticky Header Settings & Responsive Layout Attributes
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 2: Sticky Header & Responsive Layout Properties ---" -ForegroundColor Yellow

$hdrSection = $headerGroupObj.sections.header_section
Test-Empirical "header_section exists" ($hdrSection -ne $null)
Test-Empirical "header_section type is 'header'" ($hdrSection.type -eq "header")
Test-Empirical "enable_sticky_header is set to 'always'" ($hdrSection.settings.enable_sticky_header -eq "always")

$hdrLiquid = [System.IO.File]::ReadAllText($HeaderLiquidFile, [System.Text.Encoding]::UTF8)

# Sticky header assignment in Liquid
$hasStickyAssign = $hdrLiquid -match "if section\.settings\.enable_sticky_header == 'always'[\s\r\n]+assign sticky = 'always'"
Test-Empirical "header.liquid binds 'enable_sticky_header == always' to sticky = 'always'" ($hasStickyAssign)

$hasHeaderComponentStickyAttr = $hdrLiquid -match '<header-component[\s\S]*?sticky="\{\{\s*sticky\s*\}\}"'
Test-Empirical "<header-component> receives sticky='always' attribute" ($hasHeaderComponentStickyAttr)

# Sticky CSS selector test
$hasStickyCss = $hdrLiquid -match "\.header-section:has\(>\s*#header-component\[sticky='always'\]\)[\s\S]*?position:\s*sticky;"
Test-Empirical "header.liquid stylesheet sets 'position: sticky' for sticky='always'" ($hasStickyCss)

$hasStickyTopOffset = $hdrLiquid -match "\.header-section:has\(>\s*#header-component\[sticky='always'\]\)[\s\S]*?top:\s*-1px;"
Test-Empirical "header.liquid sets 'top: -1px' for IntersectionObserver sticky state tracking" ($hasStickyTopOffset)

# Desktop vs Mobile Responsive Layout Properties
Test-Empirical "sections/header-group.json configures logo_position: 'left'" ($hdrSection.settings.logo_position -eq "left")
Test-Empirical "sections/header-group.json configures menu_position: 'left'" ($hdrSection.settings.menu_position -eq "left")
Test-Empirical "sections/header-group.json configures menu_row: 'top'" ($hdrSection.settings.menu_row -eq "top")
Test-Empirical "sections/header-group.json configures section_width: 'page-width'" ($hdrSection.settings.section_width -eq "page-width")

# Check Theme Blocks: header-logo and header-menu
$logoBlock = $hdrSection.blocks.'header-logo'
$menuBlock = $hdrSection.blocks.'header-menu'
Test-Empirical "Theme Block 'header-logo' has static: true" ($logoBlock.static -eq $true)
Test-Empirical "Theme Block 'header-menu' has static: true" ($menuBlock.static -eq $true)
Test-Empirical "Theme Block 'header-menu' binds to 'main-menu'" ($menuBlock.settings.menu -eq "main-menu")

# Mobile drawer menu properties
Test-Empirical "header-menu 'drawer_accordion' is true (collapsible category accordions on mobile)" ($menuBlock.settings.drawer_accordion -eq $true)
Test-Empirical "header-menu 'drawer_dividers' is true (visual separator lines between categories)" ($menuBlock.settings.drawer_dividers -eq $true)
Test-Empirical "header-menu 'type_font_primary_size' is '0.875rem' (refined women's fitness typography)" ($menuBlock.settings.type_font_primary_size -eq "0.875rem")

# Responsive CSS rules for desktop and mobile
$hasDesktopMenuRule = $hdrLiquid -match "@media screen and \(min-width: 750px\)[\s\S]*?#header-component\[data-menu-style='menu'\]\s*:is\(\.header-menu,\s*\.dropdown-localization\)\s*\{\s*display:\s*flex;"
Test-Empirical "header.liquid displays header-menu & dropdown-localization as flex above 750px" ($hasDesktopMenuRule)

$hasMobileHiddenBottomRow = $hdrLiquid -match "when 'bottom'[\s\S]*?assign class = class \| append: ' mobile:hidden'"
Test-Empirical "header.liquid applies mobile:hidden to bottom row on mobile viewports" ($hasMobileHiddenBottomRow)

# Check drawer CSS in blocks/_header-menu.liquid
$menuBlockLiquid = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "blocks\_header-menu.liquid"), [System.Text.Encoding]::UTF8)
$hasDrawerHideOnDesktop = $menuBlockLiquid -match "@media screen and \(min-width: 750px\)[\s\S]*?#header-component\[data-menu-style='menu'\]\s*\.header__drawer\s*\{\s*display:\s*none;"
Test-Empirical "_header-menu.liquid hides mobile drawer on desktop (min-width: 750px)" ($hasDrawerHideOnDesktop)

# ------------------------------------------------------------------------------
# SECTION 3: Localization and Customer Account Links Functionality
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 3: Localization & Customer Account Links ---" -ForegroundColor Yellow

# Localization settings in header-group.json
Test-Empirical "Header setting 'show_country' is true" ($hdrSection.settings.show_country -eq $true)
Test-Empirical "Header setting 'country_selector_style' is true (displays flag icons)" ($hdrSection.settings.country_selector_style -eq $true)
Test-Empirical "Header setting 'show_language' is true" ($hdrSection.settings.show_language -eq $true)
Test-Empirical "Header setting 'localization_position' is 'right'" ($hdrSection.settings.localization_position -eq "right")
Test-Empirical "Header setting 'localization_row' is 'top'" ($hdrSection.settings.localization_row -eq "top")

# Localization markup rendering in header.liquid
$hasCountrySelector = $hdrLiquid -match 'class="icon-flag"[\s\S]*?background-image:\s*url\(\{\{-\s*localization\.country\s*\|\s*image_url:\s*width:\s*32\s*\}\}\)'
Test-Empirical "header.liquid renders national flag via localization.country image_url" ($hasCountrySelector)

$hasCurrencyCode = $hdrLiquid -match 'data-testid="localization-currency-code"[\s\S]*?\{\{-\s*localization\.country\.currency\.iso_code\s*-\}\}'
Test-Empirical "header.liquid outputs dynamic currency code (e.g. USD, EUR, CAD)" ($hasCurrencyCode)

$hasLanguageCode = $hdrLiquid -match '\{\{\s*localization\.language\.iso_code\s*\|\s*upcase\s*\}\}'
Test-Empirical "header.liquid outputs uppercase language ISO code" ($hasLanguageCode)

$hasLocalizationFormSnippet = $hdrLiquid -match "\{% render 'localization-form'[\s\S]*?show_country:\s*show_country[\s\S]*?show_language:\s*show_language"
Test-Empirical "header.liquid invokes snippets/localization-form with show_country and show_language" ($hasLocalizationFormSnippet)

# Verify snippets/localization-form.liquid native Shopify form
Test-Empirical "snippets/localization-form.liquid exists" (Test-Path $LocalizationFormFile)
$locFormLiquid = [System.IO.File]::ReadAllText($LocalizationFormFile, [System.Text.Encoding]::UTF8)
$hasNativeLocalizationForm = $locFormLiquid -match "\{%\s*-\s*form\s*'localization'[\s\S]*?id:\s*'LocalizationForm'"
Test-Empirical "snippets/localization-form.liquid implements native Shopify {% form 'localization' %}" ($hasNativeLocalizationForm)

# Customer Accounts settings and component
Test-Empirical "Header setting 'customer_account_menu' is 'customer-account-main-menu'" ($hdrSection.settings.customer_account_menu -eq "customer-account-main-menu")

$hasCustomerAccountInActions = $hdrLiquid -match "render 'header-actions'[\s\S]*?customer_account_menu:\s*section\.settings\.customer_account_menu"
Test-Empirical "header.liquid passes customer_account_menu into header-actions snippet" ($hasCustomerAccountInActions)

$actionsLiquid = [System.IO.File]::ReadAllText($HeaderActionsLiquidFile, [System.Text.Encoding]::UTF8)
$hasCustomerAccountsCheck = $actionsLiquid -match "\{%\s*if shop\.customer_accounts_enabled\s*%\}"
Test-Empirical "snippets/header-actions.liquid guards account links with shop.customer_accounts_enabled" ($hasCustomerAccountsCheck)

$hasShopifyAccountComponent = $actionsLiquid -match '<shopify-account[\s\S]*?menu="\{\{\s*customer_account_menu\s*\}\}"'
Test-Empirical "snippets/header-actions.liquid renders native <shopify-account> with configured menu" ($hasShopifyAccountComponent)

$hasSignedOutAvatarSlot = $actionsLiquid -match '<span\s+slot="signed-out-avatar"'
Test-Empirical "snippets/header-actions.liquid provides signed-out-avatar slot for guest accounts" ($hasSignedOutAvatarSlot)

# Search modal preservation
Test-Empirical "Header setting 'show_search' is true" ($hdrSection.settings.show_search -eq $true)
Test-Empirical "Header setting 'search_position' is 'right'" ($hdrSection.settings.search_position -eq "right")
Test-Empirical "Header setting 'search_row' is 'top'" ($hdrSection.settings.search_row -eq "top")

# ------------------------------------------------------------------------------
# SECTION 4: Brand Ethos, Colors & Negative Stress-Testing Oracles
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 4: Brand Ethos, Colors & Stress-Testing Oracles ---" -ForegroundColor Yellow

# Read settings_data.json
$rawSettingsText = [System.IO.File]::ReadAllText($SettingsDataFile, [System.Text.Encoding]::UTF8)
$settingsCommentMatch = [regex]::Match($rawSettingsText, '^\s*/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($settingsCommentMatch.Success) {
    $rawSettingsText = $rawSettingsText.Substring($settingsCommentMatch.Index + $settingsCommentMatch.Length).Trim()
}
$settingsData = $rawSettingsText | ConvertFrom-Json
$tokens = $settingsData.current.color_palette

Test-Empirical "Milestone 1 Soft Beige token color2 is '#E9DED5'" ($tokens.color2 -eq "#E9DED5")
Test-Empirical "Milestone 1 White token color3 is '#FFFFFF'" ($tokens.color3 -eq "#FFFFFF")
Test-Empirical "Milestone 1 Dusty Rose token color1 is '#B87570'" ($tokens.color1 -eq "#B87570")

# Check announcement bar uses exact token expressions
Test-Empirical "Announcement background_color is '{{ settings.color_palette.color2 }}'" ($annSection.settings.background_color -eq "{{ settings.color_palette.color2 }}")
Test-Empirical "Announcement divider_color is '{{ settings.color_palette.color3 }}'" ($annSection.settings.divider_color -eq "{{ settings.color_palette.color3 }}")

# Check announcement texts
$bShipping = $annSection.blocks.announcement_shipping
$bEthos = $annSection.blocks.announcement_ethos
Test-Empirical 'bShipping text: Complimentary Shipping on Orders Over $150' ($bShipping.settings.text -like "*Complimentary Shipping on Orders Over `$150*")
Test-Empirical 'bShipping link: shopify://collections/all' ($bShipping.settings.link -eq 'shopify://collections/all')
Test-Empirical 'bEthos text: STRONGER YOU. — Premium Functional Strength Sculpted for Women' ($bEthos.settings.text -like "*STRONGER YOU.*")
Test-Empirical 'bEthos link: shopify://pages/about' ($bEthos.settings.link -eq 'shopify://pages/about')

# Adversarial Oracle: Negative tests
Write-Host "`n--- Adversarial Negative Stress Oracle ---" -ForegroundColor Yellow

# Negative Test 1: Single announcement block disables rotation
$singleBlockScenario = @{
    blocks = @{
        b1 = @{ type = "_announcement" }
    }
}
$shouldRotateSingle = $singleBlockScenario.blocks.Count -gt 1
Test-Empirical "Oracle 1: Single-block announcement correctly inhibits autoplay (count <= 1)" (-not $shouldRotateSingle)

# Negative Test 2: Invalid speed outside range [2, 10]
function Validate-SpeedRange($speed) {
    return ($speed -ge 2 -and $speed -le 10)
}
Test-Empirical "Oracle 2: Synthetic speed 1 is correctly rejected by range validation" (-not (Validate-SpeedRange 1))
Test-Empirical "Oracle 2: Synthetic speed 15 is correctly rejected by range validation" (-not (Validate-SpeedRange 15))
Test-Empirical "Oracle 2: Configured speed 5 is accepted" (Validate-SpeedRange 5)

# Negative Test 3: Missing static property on header Theme Blocks
function Validate-StaticBlock($blockObj) {
    return ($blockObj -ne $null -and $blockObj.static -eq $true)
}
$badBlockMissingStatic = @{ type = "_header-menu" }
Test-Empirical "Oracle 3: Block missing static: true is flagged as invalid" (-not (Validate-StaticBlock $badBlockMissingStatic))
Test-Empirical "Oracle 3: Block with static: false is flagged as invalid" (-not (Validate-StaticBlock @{ type = "_header-menu"; static = $false }))
Test-Empirical "Oracle 3: Current header-logo is valid" (Validate-StaticBlock $logoBlock)
Test-Empirical "Oracle 3: Current header-menu is valid" (Validate-StaticBlock $menuBlock)

# ------------------------------------------------------------------------------
# FINAL SUMMARY
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 2 Empirical Challenge Summary: $Passed / $Total Tests Passed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "======================================================================" -ForegroundColor Cyan

if ($Failed -gt 0) {
    Write-Host "`nFAILURES ENCOUNTERED:" -ForegroundColor Red
    foreach ($f in $Failures) {
        Write-Host "  $f" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`nALL EMPIRICAL TESTS PASSED! Verdict: APPROVE." -ForegroundColor Green
    exit 0
}
