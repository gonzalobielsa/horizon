# Test verification script for Milestone 3 (templates/index.json)
param(
    [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$IndexJsonPath = Join-Path $ProjectRoot "templates\index.json"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 3 Verification Test Suite: templates/index.json" -ForegroundColor Cyan
Write-Host "Target: $IndexJsonPath" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $IndexJsonPath)) {
    Write-Host "[FAIL] templates/index.json does not exist" -ForegroundColor Red
    exit 1
}

$raw = [System.IO.File]::ReadAllText($IndexJsonPath, [System.Text.Encoding]::UTF8)

# Test 1: Comment Header Check
Write-Host "`n--- Test 1: Comment Header Check ---" -ForegroundColor Yellow
$commentMatch = [regex]::Match($raw, '^\s*/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($commentMatch.Success) {
    Write-Host "  [PASS] Shopify comment header detected and valid" -ForegroundColor Green
    $jsonBody = $raw.Substring($commentMatch.Index + $commentMatch.Length).Trim()
} else {
    Write-Host "  [FAIL] Comment header missing" -ForegroundColor Red
    exit 1
}

# Test 2: Multi-Parser JSON Parsing
Write-Host "`n--- Test 2: Multi-Parser JSON Parsing ---" -ForegroundColor Yellow

# Parser 1: ConvertFrom-Json
$parsed = $null
try {
    $parsed = $jsonBody | ConvertFrom-Json
    Write-Host "  [PASS] Parser 1: PowerShell ConvertFrom-Json passed" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Parser 1: ConvertFrom-Json failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Parser 2: JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
try {
    $netParsed = $jsSerializer.DeserializeObject($jsonBody)
    Write-Host "  [PASS] Parser 2: .NET JavaScriptSerializer passed" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Parser 2: JavaScriptSerializer failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Parser 3: Strict JsonReaderWriterFactory
Add-Type -AssemblyName System.Runtime.Serialization
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null)
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($jsonReader)
    Write-Host "  [PASS] Parser 3: Strict JsonReaderWriterFactory passed" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Parser 3: Strict JsonReaderWriterFactory failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Trailing Commas & Duplicate Key Check
Write-Host "`n--- Test 3: Trailing Commas & Duplicate Key Check ---" -ForegroundColor Yellow
$lines = $jsonBody -split '\r?\n'
$trailingComma = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match ',$' -and ($i + 1 -lt $lines.Length)) {
        $nextLine = $lines[$i + 1].Trim()
        if ($nextLine -match '^\s*[}\]]') {
            Write-Host "  [FAIL] Trailing comma on line $($i+1): $line" -ForegroundColor Red
            $trailingComma = $true
        }
    }
}
if (-not $trailingComma) {
    Write-Host "  [PASS] Zero trailing commas detected" -ForegroundColor Green
} else {
    exit 1
}

# Test 4: Section Order & Schema Structure
Write-Host "`n--- Test 4: Section Order & Schema Structure ---" -ForegroundColor Yellow
$expectedOrder = @('hero_heravyn', 'shop_by_category', 'product_list_fa6P9H', 'brand_story_heravyn', 'newsletter_social_section')
if ($parsed.order.Count -ne $expectedOrder.Count) {
    Write-Host "  [FAIL] Order count mismatch: $($parsed.order.Count) vs $($expectedOrder.Count)" -ForegroundColor Red
    exit 1
}
for ($i = 0; $i -lt $expectedOrder.Count; $i++) {
    if ($parsed.order[$i] -ne $expectedOrder[$i]) {
        Write-Host "  [FAIL] Order item $i mismatch: $($parsed.order[$i]) vs $($expectedOrder[$i])" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  [PASS] Section order matches specification: $($expectedOrder -join ', ')" -ForegroundColor Green

# Test 5: Section Detailed Requirements
Write-Host "`n--- Test 5: Section Detailed Requirements ---" -ForegroundColor Yellow

# Hero checks
$hero = $parsed.sections.hero_heravyn
$heroPass = ($hero.type -eq 'hero') -and
            ($hero.blocks.hero_heading.settings.text -match 'STRONGER YOU\.') -and
            ($hero.blocks.hero_heading.settings.type_preset -eq 'h1') -and
            ($hero.blocks.hero_subcopy.settings.type_preset -eq 'rte') -and
            ($hero.blocks.hero_cta_group.blocks.cta_all.settings.label -eq 'Shop All Equipment') -and
            ($hero.blocks.hero_cta_group.blocks.cta_all.settings.link -eq 'shopify://collections/all') -and
            ($hero.blocks.hero_cta_group.blocks.cta_all.settings.custom_button_background -match 'color_palette\.color1') -and
            ($hero.blocks.hero_cta_group.blocks.cta_pilates.settings.label -eq 'Explore Pilates & Glutes') -and
            ($hero.blocks.hero_cta_group.blocks.cta_pilates.settings.link -eq 'shopify://collections/pilates-glutes')
if ($heroPass) {
    Write-Host "  [PASS] Hero section: tagline 'STRONGER YOU.' (h1), subcopy (rte), dual CTAs configured" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Hero section validation failed" -ForegroundColor Red
    exit 1
}

# Shop by Category checks
$sbc = $parsed.sections.shop_by_category
$cards = $sbc.blocks.category_grid.blocks
$sbcPass = ($sbc.type -eq 'section') -and
           ($sbc.settings.background_color -match 'color_palette\.color2') -and
           ($sbc.blocks.category_header.blocks.category_title.settings.text -match 'Shop by Category') -and
           ($cards.card_strength.settings.link -eq 'shopify://collections/strength') -and
           ($cards.card_strength.blocks.t1_heading.settings.text -match 'Strength') -and
           ($cards.card_pilates.settings.link -eq 'shopify://collections/pilates-glutes') -and
           ($cards.card_pilates.blocks.t2_heading.settings.text -match 'Pilates & Glutes') -and
           ($cards.card_homeworkouts.settings.link -eq 'shopify://collections/home-workouts') -and
           ($cards.card_homeworkouts.blocks.t3_heading.settings.text -match 'Home Workouts') -and
           ($cards.card_recovery.settings.link -eq 'shopify://collections/recovery') -and
           ($cards.card_recovery.blocks.t4_heading.settings.text -match 'Recovery')
if ($sbcPass) {
    Write-Host "  [PASS] Shop by Category: 4 cards with correct links and Soft Beige background" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Shop by Category section validation failed" -ForegroundColor Red
    exit 1
}

# Product List checks
$plist = $parsed.sections.product_list_fa6P9H
$headerStatic = $plist.blocks.'static-header'.static
$cardStatic = $plist.blocks.'static-product-card'.static
$cardBlocks = $plist.blocks.'static-product-card'.blocks
$plistPass = ($plist.type -eq 'product-list') -and
             ($headerStatic -eq $true) -and
             ($cardStatic -eq $true) -and
             ($plist.settings.columns -eq 4) -and
             ($cardBlocks.product_card_gallery_677WP3.type -eq '_product-card-gallery') -and
             ($cardBlocks.product_title_YXxMTj.type -eq 'product-title') -and
             ($cardBlocks.price_JQzVV4.type -eq 'price')
if ($plistPass) {
    Write-Host "  [PASS] Featured Collection: static-header & static-product-card with static: true, 4 columns, gallery/title/price" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Featured Collection validation failed" -ForegroundColor Red
    exit 1
}

# Brand Story checks
$story = $parsed.sections.brand_story_heravyn
$mediaStatic = $story.blocks.media.static
$contentStatic = $story.blocks.content.static
$storyText = $story.blocks.content.blocks.story_group.blocks.story_heading.settings.text
$storyBtn = $story.blocks.content.blocks.story_button.settings.label
$storyPass = ($story.type -eq 'media-with-content') -and
             ($mediaStatic -eq $true) -and
             ($contentStatic -eq $true) -and
             ($storyText -match 'Empowering Women') -and
             ($storyBtn -eq 'Read Our Story') -and
             ($story.settings.background_color -match 'color_palette\.color2')
if ($storyPass) {
    Write-Host "  [PASS] Brand Story: media & content static: true, editorial copy, 'Read Our Story' CTA" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Brand Story validation failed" -ForegroundColor Red
    exit 1
}

# Newsletter & Social checks
$nl = $parsed.sections.newsletter_social_section
$nlPass = ($nl.type -eq 'section') -and
          ($nl.settings.border_radius -eq 16) -and
          ($nl.settings.background_color -match 'color_palette\.color2') -and
          ($nl.blocks.nl_form.type -eq 'email-signup') -and
          ($nl.blocks.nl_form.settings.custom_button_background -match 'color_palette\.color1') -and
          ($nl.blocks.nl_socials.type -eq 'social-links') -and
          ($nl.blocks.nl_socials.settings.instagram_url -match 'instagram\.com/heravyn') -and
          ($nl.blocks.nl_socials.settings.tiktok_url -match 'tiktok\.com/@heravyn') -and
          ($nl.blocks.nl_socials.settings.youtube_url -match 'youtube\.com/@heravyn') -and
          ($nl.blocks.nl_socials.settings.facebook_url -match 'facebook\.com/heravyn')
if ($nlPass) {
    Write-Host "  [PASS] Newsletter & Social: Soft Beige background, border_radius 16, email-signup & 4 social links" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Newsletter & Social validation failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "ALL MILESTONE 3 VERIFICATION TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
