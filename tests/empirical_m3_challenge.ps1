# ==============================================================================
# HERAVYN Milestone 3 - Empirical Adversarial Challenge Suite (challenger_m3_2)
# Scope: Responsiveness, Category Content, Theme Editor Live-Reload, Schema Integrity
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
Write-Host "HERAVYN Milestone 3 Empirical Adversarial Challenge Suite" -ForegroundColor Cyan
Write-Host "Challenger Agent: challenger_m3_2 | Operating System: Windows PowerShell" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$IndexJsonPath = Join-Path $ProjectRoot "templates\index.json"
$SettingsJsonPath = Join-Path $ProjectRoot "config\settings_data.json"

# ------------------------------------------------------------------------------
# SECTION 1: File Existence & Multi-Engine JSON Parsing
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 1: File Existence & Multi-Engine JSON Parsing ---" -ForegroundColor Yellow

Test-Empirical "templates/index.json exists" (Test-Path $IndexJsonPath)
$rawIndex = [System.IO.File]::ReadAllText($IndexJsonPath, [System.Text.Encoding]::UTF8)

# Check Shopify comment header
$commentMatch = [regex]::Match($rawIndex, '^\s*/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Test-Empirical "Shopify auto-generated comment header is present" ($commentMatch.Success)

$jsonBody = $rawIndex.Substring($commentMatch.Index + $commentMatch.Length).Trim()

# Engine 1: PowerShell ConvertFrom-Json
$parsedIndex = $null
try {
    $parsedIndex = $jsonBody | ConvertFrom-Json
    Test-Empirical "Engine 1 (ConvertFrom-Json) parses index.json" ($null -ne $parsedIndex)
} catch {
    Test-Empirical "Engine 1 (ConvertFrom-Json) parses index.json" $false $_.Exception.Message
}

# Engine 2: JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
try {
    $netParsed = $jsSerializer.DeserializeObject($jsonBody)
    Test-Empirical "Engine 2 (.NET JavaScriptSerializer) parses index.json" ($null -ne $netParsed)
} catch {
    Test-Empirical "Engine 2 (.NET JavaScriptSerializer) parses index.json" $false $_.Exception.Message
}

# Engine 3: Strict JsonReaderWriterFactory
Add-Type -AssemblyName System.Runtime.Serialization
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $reader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null)
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($reader)
    Test-Empirical "Engine 3 (Strict JsonReaderWriterFactory) parses index.json" ($null -ne $xmlDoc)
} catch {
    Test-Empirical "Engine 3 (Strict JsonReaderWriterFactory) parses index.json" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# SECTION 2: Trailing Commas, Unclosed Brackets, and Syntax Rigor
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 2: Trailing Commas, Unclosed Brackets, and Syntax Rigor ---" -ForegroundColor Yellow

# Check trailing commas before closing braces/brackets
$lines = $jsonBody -split '\r?\n'
$hasTrailingComma = $false
$trailingCommaLines = @()
for ($i = 0; $i -lt $lines.Length; $i++) {
    $trimLine = $lines[$i].Trim()
    if ($trimLine.EndsWith(',')) {
        for ($j = $i + 1; $j -lt $lines.Length; $j++) {
            $nextTrim = $lines[$j].Trim()
            if ($nextTrim -eq '') { continue }
            if ($nextTrim.StartsWith('}') -or $nextTrim.StartsWith(']')) {
                $hasTrailingComma = $true
                $trailingCommaLines += ($i + 1)
            }
            break
        }
    }
}
Test-Empirical "Zero trailing commas before closing braces/brackets" (-not $hasTrailingComma) "Found at lines: $($trailingCommaLines -join ', ')"

# Check bracket balance
$openBraces = ($jsonBody.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$closeBraces = ($jsonBody.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Test-Empirical "Curly brace count strictly balanced ($openBraces vs $closeBraces)" ($openBraces -eq $closeBraces)

$openBrackets = ($jsonBody.ToCharArray() | Where-Object { $_ -eq '[' }).Count
$closeBrackets = ($jsonBody.ToCharArray() | Where-Object { $_ -eq ']' }).Count
Test-Empirical "Square bracket count strictly balanced ($openBrackets vs $closeBrackets)" ($openBrackets -eq $closeBrackets)

# ------------------------------------------------------------------------------
# SECTION 3: Section Hierarchy, Ordering, and Block Bijective Mapping
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 3: Section Hierarchy, Ordering, and Block Bijective Mapping ---" -ForegroundColor Yellow

$expectedOrder = @('hero_heravyn', 'shop_by_category', 'product_list_fa6P9H', 'brand_story_heravyn', 'newsletter_social_section')
$actualOrder = @($parsedIndex.order)

Test-Empirical "Order array has exactly 5 sections" ($actualOrder.Count -eq 5) "Got $($actualOrder.Count)"
Test-Empirical "Order array sequence strictly matches specification" (($actualOrder -join ',') -eq ($expectedOrder -join ',')) "Got $($actualOrder -join ',')"

# Bijective check: Every section in order exists in sections object, and vice versa
$sectionsObj = $parsedIndex.sections
$sectionKeys = @($sectionsObj.PSObject.Properties | ForEach-Object { $_.Name })
$missingInSections = $actualOrder | Where-Object { $sectionKeys -notcontains $_ }
$extraInSections = $sectionKeys | Where-Object { $actualOrder -notcontains $_ }

Test-Empirical "All ordered sections exist in sections dictionary" ($missingInSections.Count -eq 0) "Missing: $($missingInSections -join ', ')"
Test-Empirical "No ghost sections exist in sections dictionary" ($extraInSections.Count -eq 0) "Ghost sections: $($extraInSections -join ', ')"

# Block order bijective check for each section and group block
function Check-BlocksBijective($container, $pathName) {
    if ($null -eq $container.blocks -or $null -eq $container.block_order) { return }
    $bKeys = @($container.blocks.PSObject.Properties | ForEach-Object { $_.Name })
    $bOrder = @($container.block_order)
    
    $missingOrder = $bKeys | Where-Object { $bOrder -notcontains $_ }
    $missingBlocks = $bOrder | Where-Object { $bKeys -notcontains $_ }
    
    Test-Empirical "Block order in '$pathName' is bijective" ($missingOrder.Count -eq 0 -and $missingBlocks.Count -eq 0) "Missing in order: $($missingOrder -join ', '), Missing in blocks: $($missingBlocks -join ', ')"
    
    # Recurse into child blocks
    foreach ($k in $bKeys) {
        $child = $container.blocks.$k
        Check-BlocksBijective $child "$pathName -> $k"
    }
}

foreach ($sKey in $sectionKeys) {
    Check-BlocksBijective $sectionsObj.$sKey "sections.$sKey"
}

# ------------------------------------------------------------------------------
# SECTION 4: Theme Editor Live-Reload Readiness & Schema Conformance
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 4: Theme Editor Live-Reload Readiness & Schema Conformance ---" -ForegroundColor Yellow

# Verify all section .liquid files exist
foreach ($sKey in $sectionKeys) {
    $sec = $sectionsObj.$sKey
    $secType = $sec.type
    $secFile = Join-Path $ProjectRoot "sections\$secType.liquid"
    Test-Empirical "Section file 'sections\$secType.liquid' exists for '$sKey'" (Test-Path $secFile)
}

# Verify all block .liquid files exist recursively
function Check-BlockTypesExist($container, $pathName) {
    if ($null -eq $container.blocks) { return }
    $bKeys = @($container.blocks.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($k in $bKeys) {
        $child = $container.blocks.$k
        $bType = $child.type
        $bFile = Join-Path $ProjectRoot "blocks\$bType.liquid"
        Test-Empirical "Block file 'blocks\$bType.liquid' exists for '$pathName -> $k'" (Test-Path $bFile)
        Check-BlockTypesExist $child "$pathName -> $k"
    }
}

foreach ($sKey in $sectionKeys) {
    Check-BlockTypesExist $sectionsObj.$sKey "sections.$sKey"
}

# Check static blocks in product-list
$productList = $sectionsObj.product_list_fa6P9H
Test-Empirical "product-list static-header block exists" ($null -ne $productList.blocks.'static-header')
Test-Empirical "product-list static-header has static: true" ($productList.blocks.'static-header'.static -eq $true)
Test-Empirical "product-list static-header type is '_product-list-content'" ($productList.blocks.'static-header'.type -eq '_product-list-content')

Test-Empirical "product-list static-product-card block exists" ($null -ne $productList.blocks.'static-product-card')
Test-Empirical "product-list static-product-card has static: true" ($productList.blocks.'static-product-card'.static -eq $true)
Test-Empirical "product-list static-product-card type is '_product-card'" ($productList.blocks.'static-product-card'.type -eq '_product-card')

# Check static blocks in media-with-content
$brandStory = $sectionsObj.brand_story_heravyn
Test-Empirical "media-with-content media block exists" ($null -ne $brandStory.blocks.media)
Test-Empirical "media-with-content media has static: true" ($brandStory.blocks.media.static -eq $true)
Test-Empirical "media-with-content media type is '_media-without-appearance'" ($brandStory.blocks.media.type -eq '_media-without-appearance')

Test-Empirical "media-with-content content block exists" ($null -ne $brandStory.blocks.content)
Test-Empirical "media-with-content content has static: true" ($brandStory.blocks.content.static -eq $true)
Test-Empirical "media-with-content content type is '_content-without-appearance'" ($brandStory.blocks.content.type -eq '_content-without-appearance')

# ------------------------------------------------------------------------------
# SECTION 5: Responsiveness Verification (Mobile vs Desktop)
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 5: Responsiveness Verification ---" -ForegroundColor Yellow

# Product list columns
Test-Empirical "product-list layout_type is 'grid'" ($productList.settings.layout_type -eq 'grid')
Test-Empirical "product-list desktop columns is integer 4" ($productList.settings.columns -eq 4)
Test-Empirical "product-list mobile_columns is string '2'" ($productList.settings.mobile_columns -eq "2")
Test-Empirical "product-list carousel_on_mobile is false (enables 2-column mobile grid)" ($productList.settings.carousel_on_mobile -eq $false)

# Category grid responsiveness
$shopCat = $sectionsObj.shop_by_category
$catGrid = $shopCat.blocks.category_grid
Test-Empirical "Category grid has vertical_on_mobile: true" ($catGrid.settings.vertical_on_mobile -eq $true)
Test-Empirical "Category grid content_direction is 'row'" ($catGrid.settings.content_direction -eq 'row')

# Verify 4 cards each have desktop width 25% and mobile fill (100%)
$cards = @('card_strength', 'card_pilates', 'card_homeworkouts', 'card_recovery')
foreach ($cKey in $cards) {
    $card = $catGrid.blocks.$cKey
    Test-Empirical "$cKey width is 'custom' and custom_width is 25" ($card.settings.width -eq 'custom' -and $card.settings.custom_width -eq 25)
    Test-Empirical "$cKey width_mobile is 'fill' and custom_width_mobile is 100" ($card.settings.width_mobile -eq 'fill' -and $card.settings.custom_width_mobile -eq 100)
    Test-Empirical "$cKey vertical_on_mobile is true" ($card.settings.vertical_on_mobile -eq $true)
}

# Hero CTAs responsiveness
$heroCtaGroup = $sectionsObj.hero_heravyn.blocks.hero_cta_group
Test-Empirical "Hero CTA group has vertical_on_mobile: true" ($heroCtaGroup.settings.vertical_on_mobile -eq $true)
Test-Empirical "Hero CTA group width_mobile is 'fill'" ($heroCtaGroup.settings.width_mobile -eq 'fill')
Test-Empirical "Hero CTA 1 (cta_all) width_mobile is 'fill'" ($heroCtaGroup.blocks.cta_all.settings.width_mobile -eq 'fill')
Test-Empirical "Hero CTA 2 (cta_pilates) width_mobile is 'fill'" ($heroCtaGroup.blocks.cta_pilates.settings.width_mobile -eq 'fill')

# Newsletter form responsiveness
$nlForm = $sectionsObj.newsletter_social_section.blocks.nl_form
Test-Empirical "Newsletter form width is 'custom' (55% desktop)" ($nlForm.settings.width -eq 'custom' -and $nlForm.settings.custom_width -eq 55)
Test-Empirical "Newsletter form width_mobile is 'fill' (100% mobile)" ($nlForm.settings.width_mobile -eq 'fill')

# ------------------------------------------------------------------------------
# SECTION 6: Category Cards Content, Descriptions, and Collection Links
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 6: Category Cards Content, Descriptions, and Links ---" -ForegroundColor Yellow

$categorySpecs = @(
    @{
        Key = 'card_strength'
        TitlePattern = 'Strength'
        ExpectedSub = 'Dumbbells, barbells, kettlebells, weight plates'
        Link = 'shopify://collections/strength'
        BtnLabel = 'Explore Strength'
        SubBlock = 't1_sub'
        HeadingBlock = 't1_heading'
        BtnBlock = 't1_btn'
    },
    @{
        Key = 'card_pilates'
        TitlePattern = 'Pilates & Glutes'
        ExpectedSub = 'Resistance bands, ankle weights, sliders, mats'
        Link = 'shopify://collections/pilates-glutes'
        BtnLabel = 'Explore Pilates & Glutes'
        SubBlock = 't2_sub'
        HeadingBlock = 't2_heading'
        BtnBlock = 't2_btn'
    },
    @{
        Key = 'card_homeworkouts'
        TitlePattern = 'Home Workouts'
        ExpectedSub = 'Compact benches, pull-up systems, adjustable sets'
        Link = 'shopify://collections/home-workouts'
        BtnLabel = 'Explore Home Workouts'
        SubBlock = 't3_sub'
        HeadingBlock = 't3_heading'
        BtnBlock = 't3_btn'
    },
    @{
        Key = 'card_recovery'
        TitlePattern = 'Recovery'
        ExpectedSub = 'Foam rollers, massage balls, acupressure, straps'
        Link = 'shopify://collections/recovery'
        BtnLabel = 'Explore Recovery'
        SubBlock = 't4_sub'
        HeadingBlock = 't4_heading'
        BtnBlock = 't4_btn'
    }
)

foreach ($spec in $categorySpecs) {
    $card = $catGrid.blocks.($spec.Key)
    Test-Empirical "Category card '$($spec.Key)' exists in category_grid" ($null -ne $card)
    
    # Outer link
    Test-Empirical "$($spec.Key) outer card link is '$($spec.Link)'" ($card.settings.link -eq $spec.Link)
    
    # Border radius
    Test-Empirical "$($spec.Key) border_radius is 12" ($card.settings.border_radius -eq 12)
    
    # Heading
    $headingBlock = $card.blocks.($spec.HeadingBlock)
    Test-Empirical "$($spec.Key) heading contains '$($spec.TitlePattern)'" ($headingBlock.settings.text -match $spec.TitlePattern)
    
    # Description
    $subBlock = $card.blocks.($spec.SubBlock)
    $cleanSub = ($subBlock.settings.text -replace '<[^>]+>', '').Trim()
    Test-Empirical "$($spec.Key) equipment description is non-empty" (-not [string]::IsNullOrWhiteSpace($cleanSub))
    Test-Empirical "$($spec.Key) equipment description strictly equals '$($spec.ExpectedSub)'" ($cleanSub -eq $spec.ExpectedSub) "Got: '$cleanSub'"
    
    # Button
    $btnBlock = $card.blocks.($spec.BtnBlock)
    Test-Empirical "$($spec.Key) button label is '$($spec.BtnLabel)'" ($btnBlock.settings.label -eq $spec.BtnLabel)
    Test-Empirical "$($spec.Key) button link matches outer link '$($spec.Link)'" ($btnBlock.settings.link -eq $spec.Link)
}

# ------------------------------------------------------------------------------
# SECTION 7: Email Signup Tokens, Styles, and Social Links
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 7: Email Signup Tokens, Styles, and Social Links ---" -ForegroundColor Yellow

$nlSec = $sectionsObj.newsletter_social_section
Test-Empirical "Newsletter section background is Soft Beige token '{{ settings.color_palette.color2 }}'" ($nlSec.settings.background_color -eq '{{ settings.color_palette.color2 }}')
Test-Empirical "Newsletter section border_radius is 16" ($nlSec.settings.border_radius -eq 16)

$nlForm = $nlSec.blocks.nl_form
Test-Empirical "Email-signup block type is 'email-signup'" ($nlForm.type -eq 'email-signup')
Test-Empirical "Email-signup input_style is 'custom'" ($nlForm.settings.input_style -eq 'custom')
Test-Empirical "Email-signup border_radius is 100 (pill input)" ($nlForm.settings.border_radius -eq 100)
Test-Empirical "Email-signup input_background_color is '{{ settings.color_palette.background }}'" ($nlForm.settings.input_background_color -eq '{{ settings.color_palette.background }}')
Test-Empirical "Email-signup input_border_color is '{{ settings.color_palette.color3 }}'" ($nlForm.settings.input_border_color -eq '{{ settings.color_palette.color3 }}')
Test-Empirical "Email-signup style_class is 'button-custom'" ($nlForm.settings.style_class -eq 'button-custom')
Test-Empirical "Email-signup custom_button_background is '{{ settings.color_palette.color1 }}'" ($nlForm.settings.custom_button_background -eq '{{ settings.color_palette.color1 }}')
Test-Empirical "Email-signup custom_button_text is '#FFFFFF'" ($nlForm.settings.custom_button_text -eq '#FFFFFF')
Test-Empirical "Email-signup custom_button_border is '{{ settings.color_palette.color1 }}'" ($nlForm.settings.custom_button_border -eq '{{ settings.color_palette.color1 }}')
Test-Empirical "Email-signup label is 'Join Now'" ($nlForm.settings.label -eq 'Join Now')
Test-Empirical "Email-signup integrated_button is false" ($nlForm.settings.integrated_button -eq $false)

# Social links
$nlSocials = $nlSec.blocks.nl_socials
Test-Empirical "Social-links block type is 'social-links'" ($nlSocials.type -eq 'social-links')
Test-Empirical "Instagram URL populated" ($nlSocials.settings.instagram_url -eq 'https://www.instagram.com/heravyn')
Test-Empirical "TikTok URL populated" ($nlSocials.settings.tiktok_url -eq 'https://www.tiktok.com/@heravyn')
Test-Empirical "YouTube URL populated" ($nlSocials.settings.youtube_url -eq 'https://www.youtube.com/@heravyn')
Test-Empirical "Facebook URL populated" ($nlSocials.settings.facebook_url -eq 'https://www.facebook.com/heravyn')

# ------------------------------------------------------------------------------
# SECTION 8: Hero Section & Brand Story Tagline & Ethos
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 8: Hero Section & Brand Story Tagline & Ethos ---" -ForegroundColor Yellow

$heroSec = $sectionsObj.hero_heravyn
$heroH1 = $heroSec.blocks.hero_heading.settings.text
Test-Empirical "Hero heading strictly contains 'STRONGER YOU.'" ($heroH1 -match 'STRONGER YOU\.')
Test-Empirical "Hero heading type_preset is 'h1'" ($heroSec.blocks.hero_heading.settings.type_preset -eq 'h1')
Test-Empirical "Hero subcopy mentions 'functional strength' and 'women'" ($heroSec.blocks.hero_subcopy.settings.text -match 'functional strength' -and $heroSec.blocks.hero_subcopy.settings.text -match 'women')

$ctaAll = $heroCtaGroup.blocks.cta_all
Test-Empirical "Hero CTA 1 label is 'Shop All Equipment'" ($ctaAll.settings.label -eq 'Shop All Equipment')
Test-Empirical "Hero CTA 1 links to 'shopify://collections/all'" ($ctaAll.settings.link -eq 'shopify://collections/all')
Test-Empirical "Hero CTA 1 uses Dusty Rose accent '{{ settings.color_palette.color1 }}'" ($ctaAll.settings.custom_button_background -eq '{{ settings.color_palette.color1 }}')

$ctaPilates = $heroCtaGroup.blocks.cta_pilates
Test-Empirical "Hero CTA 2 label is 'Explore Pilates & Glutes'" ($ctaPilates.settings.label -eq 'Explore Pilates & Glutes')
Test-Empirical "Hero CTA 2 links to 'shopify://collections/pilates-glutes'" ($ctaPilates.settings.link -eq 'shopify://collections/pilates-glutes')

# Brand story
$storyContent = $brandStory.blocks.content.blocks
Test-Empirical "Brand story caption is 'THE HERAVYN PHILOSOPHY'" ($storyContent.story_caption.settings.text -match 'THE HERAVYN PHILOSOPHY')
Test-Empirical "Brand story heading communicates mission" ($storyContent.story_group.blocks.story_heading.settings.text -match 'Empowering Women Through Functional Strength')
Test-Empirical "Brand story button links to 'shopify://pages/about'" ($storyContent.story_button.settings.link -eq 'shopify://pages/about')

# ------------------------------------------------------------------------------
# SECTION 9: Liquid Tag Balancing in Touched & Referenced Files
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 9: Liquid Tag Balancing in Referenced Files ---" -ForegroundColor Yellow

$liquidFilesToCheck = @(
    "sections\hero.liquid",
    "sections\section.liquid",
    "sections\product-list.liquid",
    "sections\media-with-content.liquid",
    "blocks\email-signup.liquid",
    "blocks\group.liquid",
    "blocks\social-links.liquid",
    "blocks\_product-list-content.liquid",
    "blocks\_product-card.liquid"
)

foreach ($relPath in $liquidFilesToCheck) {
    $fullPath = Join-Path $ProjectRoot $relPath
    if (-not (Test-Path $fullPath)) {
        Test-Empirical "File $relPath exists" $false
        continue
    }
    $content = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    
    # Check if / endif
    $ifCount = [regex]::Matches($content, '\{%-?\s*if\b').Count
    $endifCount = [regex]::Matches($content, '\{%-?\s*endif\b').Count
    Test-Empirical "${relPath} - 'if' count equals 'endif' count ($ifCount vs $endifCount)" ($ifCount -eq $endifCount)
    
    # Check unless / endunless
    $unlessCount = [regex]::Matches($content, '\{%-?\s*unless\b').Count
    $endunlessCount = [regex]::Matches($content, '\{%-?\s*endunless\b').Count
    Test-Empirical "${relPath} - 'unless' count equals 'endunless' count ($unlessCount vs $endunlessCount)" ($unlessCount -eq $endunlessCount)
    
    # Check case / endcase
    $caseCount = [regex]::Matches($content, '\{%-?\s*case\b').Count
    $endcaseCount = [regex]::Matches($content, '\{%-?\s*endcase\b').Count
    Test-Empirical "${relPath} - 'case' count equals 'endcase' count ($caseCount vs $endcaseCount)" ($caseCount -eq $endcaseCount)
    
    # Check schema / endschema
    $schemaCount = [regex]::Matches($content, '\{%-?\s*schema\b').Count
    $endschemaCount = [regex]::Matches($content, '\{%-?\s*endschema\b').Count
    Test-Empirical "${relPath} - 'schema' count equals 'endschema' count ($schemaCount vs $endschemaCount)" ($schemaCount -eq $endschemaCount)
}

# ------------------------------------------------------------------------------
# SECTION 10: Git Status & Cleanliness Inspection
# ------------------------------------------------------------------------------
Write-Host "`n--- Section 10: Git Status & Cleanliness Inspection ---" -ForegroundColor Yellow

$gitStatusRaw = git status --porcelain
$modifiedFiles = @()
$untrackedFiles = @()

foreach ($line in ($gitStatusRaw -split '\r?\n')) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $code = $line.Substring(0, 2)
    $path = $line.Substring(3).Trim()
    if ($code -match 'M') {
        $modifiedFiles += $path
    } elseif ($code -match '\?') {
        $untrackedFiles += $path
    }
}

Test-Empirical "templates/index.json is in modified files list" ($modifiedFiles -contains 'templates/index.json')
$unexpectedModified = $modifiedFiles | Where-Object { 
    $_ -ne 'templates/index.json' -and 
    $_ -ne 'config/settings_data.json' -and 
    $_ -ne 'sections/header-group.json' 
}
Test-Empirical "Zero unexpected core theme files modified" ($unexpectedModified.Count -eq 0) "Unexpected: $($unexpectedModified -join ', ')"

# ==============================================================================
# SUMMARY & FINAL VERDICT
# ==============================================================================
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 3 Empirical Verification Summary" -ForegroundColor Cyan
Write-Host "Total Tests Executed: $Total" -ForegroundColor Cyan
Write-Host "Passed: $Passed" -ForegroundColor Green
Write-Host "Failed: $Failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "======================================================================" -ForegroundColor Cyan

if ($Failed -gt 0) {
    Write-Host "`nFailures summary:" -ForegroundColor Red
    foreach ($f in $Failures) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    Write-Host "`nVERDICT: REQUEST_CHANGES" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nVERDICT: ALL TESTS PASSED - EMPIRICAL VERIFICATION APPROVES MILESTONE 3" -ForegroundColor Green
    exit 0
}
