# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 3 Adversarial Challenge Suite
# Reviewer: challenger_m3_1 (Critic & Specialist)
# Target: templates/index.json
# Requirements: R3 (Homepage Experience) & Project Plan Milestone 3
# ==============================================================================

param(
    [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$TotalChecks = 0
$PassedChecks = 0
$FailedChecks = 0
$Issues = @()

function Assert-Test($Name, $Condition, $Detail = "") {
    $script:TotalChecks++
    if ($Condition) {
        $script:PassedChecks++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:FailedChecks++
        $msg = "  [FAIL] ${Name}: $Detail"
        $script:Issues += $msg
        Write-Host $msg -ForegroundColor Red
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 3 Adversarial Challenge Verification Suite" -ForegroundColor Cyan
Write-Host "Target: templates/index.json" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$IndexJsonPath = Join-Path $ProjectRoot "templates\index.json"
Assert-Test "File exists: templates/index.json" (Test-Path $IndexJsonPath) "File not found"

if (-not (Test-Path $IndexJsonPath)) {
    Write-Host "Cannot proceed without templates/index.json" -ForegroundColor Red
    exit 1
}

$rawText = [System.IO.File]::ReadAllText($IndexJsonPath, [System.Text.Encoding]::UTF8)

# ------------------------------------------------------------------------------
# 1. Structural, Lexical & Multi-Parser Deserialization
# ------------------------------------------------------------------------------
Write-Host "`n--- 1. Structural, Lexical & Multi-Parser Deserialization ---" -ForegroundColor Yellow

# Comment Header Check
$commentRegex = '^\s*/\*\s*\r?\n\s*\*\s*--+.*?IMPORTANT: The contents of this file are auto-generated\..*?\*/'
$commentMatch = [regex]::Match($rawText, $commentRegex, [System.Text.RegularExpressions.RegexOptions]::Singleline)
Assert-Test "Shopify standard comment header is present and valid" ($commentMatch.Success) "Comment header missing or malformed"

$bodyText = if ($commentMatch.Success) {
    $rawText.Substring($commentMatch.Index + $commentMatch.Length).Trim()
} else {
    $rawText.Trim()
}

# Check for stray comments in JSON body
$hasStrayComments = [regex]::IsMatch($bodyText, '/\*|\*/|(?<!:)\/\/[^\r\n]*')
Assert-Test "No stray comments inside JSON body" (-not $hasStrayComments) "Stray comment markers found in JSON body"

# Trailing commas check
$trailingCommaRegex = ',\s*([\}\]])'
$trailingCommaMatches = [regex]::Matches($bodyText, $trailingCommaRegex)
Assert-Test "Zero trailing commas before closing braces/brackets" ($trailingCommaMatches.Count -eq 0) "Found $($trailingCommaMatches.Count) trailing commas"
if ($trailingCommaMatches.Count -gt 0) {
    foreach ($m in $trailingCommaMatches) {
        Write-Host "    Found trailing comma at index $($m.Index): $($m.Value)" -ForegroundColor DarkYellow
    }
}

# Parser 1: PowerShell ConvertFrom-Json
$psParsed = $null
try {
    $psParsed = $bodyText | ConvertFrom-Json
    Assert-Test "Parser 1: PowerShell ConvertFrom-Json succeeds" ($psParsed -ne $null) "Result is null"
} catch {
    Assert-Test "Parser 1: PowerShell ConvertFrom-Json succeeds" $false $_.Exception.Message
}

# Parser 2: .NET JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$jsSerializer.MaxJsonLength = [int]::MaxValue
try {
    $netParsed = $jsSerializer.DeserializeObject($bodyText)
    Assert-Test "Parser 2: .NET JavaScriptSerializer succeeds" ($netParsed -ne $null) "Result is null"
} catch {
    Assert-Test "Parser 2: .NET JavaScriptSerializer succeeds" $false $_.Exception.Message
}

# Parser 3: Strict JsonReaderWriterFactory
Add-Type -AssemblyName System.Runtime.Serialization
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyText)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null)
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($jsonReader)
    Assert-Test "Parser 3: Strict JsonReaderWriterFactory succeeds" ($xmlDoc.DocumentElement -ne $null) "Result document is null"
} catch {
    Assert-Test "Parser 3: Strict JsonReaderWriterFactory succeeds" $false $_.Exception.Message
}

# Parser 4: XML Reader Tree Walk verification
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyText)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $xr = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null)
    $nodeCount = 0
    while ($xr.Read()) {
        $nodeCount++
    }
    Assert-Test "Parser 4: Low-level JsonReader stream parsed $nodeCount nodes successfully" ($nodeCount -gt 100) "nodeCount: $nodeCount"
} catch {
    Assert-Test "Parser 4: Low-level JsonReader stream parsed nodes successfully" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# 2. Adversarial Duplicate Key Detection Across Full JSON AST
# ------------------------------------------------------------------------------
Write-Host "`n--- 2. Duplicate Key Detection Across Entire JSON Tree ---" -ForegroundColor Yellow

$csharpSource = @"
using System;
using System.Collections.Generic;
using System.Text;

public class StrictJsonDuplicateChecker {
    public static List<string> FindDuplicateKeys(string json) {
        var duplicates = new List<string>();
        int pos = 0;
        int len = json.Length;

        Action skipWs = () => {
            while (pos < len && char.IsWhiteSpace(json[pos])) pos++;
        };

        Func<string> readString = () => {
            if (pos >= len || json[pos] != '"') throw new Exception("Expected quote at " + pos);
            pos++;
            var sb = new StringBuilder();
            while (pos < len) {
                char c = json[pos++];
                if (c == '\\') {
                    if (pos >= len) throw new Exception("Unterminated escape at " + pos);
                    char esc = json[pos++];
                    if (esc == 'u') {
                        if (pos + 4 > len) throw new Exception("Invalid unicode escape at " + pos);
                        pos += 4;
                    }
                    sb.Append(esc);
                } else if (c == '"') {
                    return sb.ToString();
                } else {
                    sb.Append(c);
                }
            }
            throw new Exception("Unterminated string literal");
        };

        var pathStack = new Stack<string>();
        Action parseVal = null;

        parseVal = () => {
            skipWs();
            if (pos >= len) return;
            char c = json[pos];
            if (c == '{') {
                pos++;
                var seenKeys = new HashSet<string>(StringComparer.Ordinal);
                skipWs();
                if (pos < len && json[pos] == '}') {
                    pos++;
                    return;
                }
                while (pos < len) {
                    skipWs();
                    string key = readString();
                    skipWs();
                    if (pos >= len || json[pos] != ':') throw new Exception("Expected ':' at " + pos);
                    pos++; // skip ':'
                    
                    if (seenKeys.Contains(key)) {
                        var arr = pathStack.ToArray();
                        Array.Reverse(arr);
                        string fullPath = string.Join(".", arr) + "." + key;
                        duplicates.Add(fullPath);
                    } else {
                        seenKeys.Add(key);
                    }

                    pathStack.Push(key);
                    parseVal();
                    pathStack.Pop();

                    skipWs();
                    if (pos < len && json[pos] == ',') {
                        pos++;
                        continue;
                    } else if (pos < len && json[pos] == '}') {
                        pos++;
                        break;
                    } else {
                        throw new Exception("Expected ',' or '}' at " + pos);
                    }
                }
            } else if (c == '[') {
                pos++;
                skipWs();
                if (pos < len && json[pos] == ']') {
                    pos++;
                    return;
                }
                int idx = 0;
                while (pos < len) {
                    pathStack.Push("[" + idx + "]");
                    parseVal();
                    pathStack.Pop();
                    idx++;
                    skipWs();
                    if (pos < len && json[pos] == ',') {
                        pos++;
                        continue;
                    } else if (pos < len && json[pos] == ']') {
                        pos++;
                        break;
                    } else {
                        throw new Exception("Expected ',' or ']' at " + pos);
                    }
                }
            } else if (c == '"') {
                readString();
            } else {
                while (pos < len && json[pos] != ',' && json[pos] != '}' && json[pos] != ']' && !char.IsWhiteSpace(json[pos])) {
                    pos++;
                }
            }
        };

        parseVal();
        return duplicates;
    }
}
"@

try {
    Add-Type -TypeDefinition $csharpSource -Language CSharp
    $duplicateKeys = [StrictJsonDuplicateChecker]::FindDuplicateKeys($bodyText)
    Assert-Test "Zero duplicate keys found across entire JSON hierarchy" ($duplicateKeys.Count -eq 0) "Found duplicate keys: $($duplicateKeys -join ', ')"
} catch {
    Assert-Test "Zero duplicate keys found across entire JSON hierarchy" $false $_.Exception.Message
}

# Negative Mutation Testing Oracles
Write-Host "`n  [Negative Mutation Testing Oracles]" -ForegroundColor Cyan
$syntheticTrailingComma = '{"a": 1,}'
$trailingMatches = [regex]::Matches($syntheticTrailingComma, ',\s*([\}\]])')
Assert-Test "Negative Oracle 1: Synthetic trailing comma correctly trapped" ($trailingMatches.Count -gt 0) ""

$syntheticDupKey = '{"order": 1, "nested": {"foo": "bar", "foo": "baz"}}'
$dupMatches = [StrictJsonDuplicateChecker]::FindDuplicateKeys($syntheticDupKey)
Assert-Test "Negative Oracle 2: Synthetic duplicate key correctly trapped" ($dupMatches.Count -gt 0) ""

$syntheticUnclosed = '{"order": 1, "nested": {"foo": "bar"}'
$unclosedTrapped = $false
try {
    $null = $syntheticUnclosed | ConvertFrom-Json
} catch {
    $unclosedTrapped = $true
}
Assert-Test "Negative Oracle 3: Synthetic unclosed brace correctly trapped" $unclosedTrapped ""

# ------------------------------------------------------------------------------
# 3. Section Schema & Setting Verification Against Liquid Source Files
# ------------------------------------------------------------------------------
Write-Host "`n--- 3. Section Schema & Setting Verification Against Liquid Source Files ---" -ForegroundColor Yellow

function Get-LiquidSchema($filePath) {
    if (-not (Test-Path $filePath)) { return $null }
    $content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
    $m = [regex]::Match($content, '(?s)\{%\s*schema\s*%\}(.*?)\{%\s*endschema\s*%\}')
    if ($m.Success) {
        try {
            return $m.Groups[1].Value.Trim() | ConvertFrom-Json
        } catch {
            Write-Host "Error parsing schema in $filePath : $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
    return $null
}

function Test-SchemaSetting($schema, $settingId) {
    if ($null -eq $schema -or $null -eq $schema.settings) {
        return $false
    }
    foreach ($s in $schema.settings) {
        if ($s.id -eq $settingId) {
            return $true
        }
    }
    return $false
}

$blockSchemaCache = @{}
function Get-BlockSchemaCached($blockType) {
    if ($blockSchemaCache.ContainsKey($blockType)) {
        return $blockSchemaCache[$blockType]
    }
    $blockFile = Join-Path $ProjectRoot "blocks\$blockType.liquid"
    $schema = Get-LiquidSchema $blockFile
    $blockSchemaCache[$blockType] = $schema
    return $schema
}

function Validate-BlockTree($blocksObj, $path) {
    $errors = @()
    if ($null -eq $blocksObj) { return $errors }
    foreach ($prop in $blocksObj.PSObject.Properties) {
        $blockId = $prop.Name
        $block = $prop.Value
        $blockType = $block.type
        $schema = Get-BlockSchemaCached $blockType
        if ($null -eq $schema) {
            $errors += "Schema not found for block type '$blockType' at $path/$blockId"
        } else {
            if ($block.settings -ne $null) {
                foreach ($sprop in $block.settings.PSObject.Properties) {
                    $settingId = $sprop.Name
                    if (-not (Test-SchemaSetting $schema $settingId)) {
                        $errors += "Unknown setting '$settingId' on block '$blockId' (type: '$blockType') at $path/$blockId"
                    }
                }
            }
        }
        if ($block.blocks -ne $null) {
            $errors += Validate-BlockTree $block.blocks "$path/$blockId"
        }
    }
    return $errors
}

$sections = $psParsed.sections
$order = $psParsed.order

Assert-Test "Top-level 'sections' object is defined" ($sections -ne $null) "sections object missing"
Assert-Test "Top-level 'order' array is defined" ($order -ne $null) "order array missing"
Assert-Test "Order contains exactly 5 sections" ($order.Count -eq 5) "order count is $($order.Count)"

$expectedSections = @(
    "hero_heravyn",
    "shop_by_category",
    "product_list_fa6P9H",
    "brand_story_heravyn",
    "newsletter_social_section"
)

$orderMatches = $true
for ($i = 0; $i -lt $expectedSections.Count; $i++) {
    if ($order[$i] -ne $expectedSections[$i]) {
        $orderMatches = $false
        break
    }
}
Assert-Test "Order matches merchandising sequence: $($expectedSections -join ' -> ')" $orderMatches "Order: $($order -join ' -> ')"

foreach ($sName in $order) {
    Assert-Test "Section '$sName' exists in sections dictionary" ($sections.PSObject.Properties[$sName] -ne $null) "Missing section in sections"
}

# --- SECTION 1: hero_heravyn (sections/hero.liquid) ---
Write-Host "`n  [Section: hero_heravyn]" -ForegroundColor Cyan
$heroSec = $sections.hero_heravyn
$heroSchema = Get-LiquidSchema (Join-Path $ProjectRoot "sections\hero.liquid")
Assert-Test "hero.liquid schema parsed successfully" ($heroSchema -ne $null) "hero.liquid schema null"
Assert-Test "hero_heravyn type is 'hero'" ($heroSec.type -eq "hero") "type is '$($heroSec.type)'"

$heroInvalidSettings = @()
foreach ($prop in $heroSec.settings.PSObject.Properties) {
    $sId = $prop.Name
    if (-not (Test-SchemaSetting $heroSchema $sId)) {
        $heroInvalidSettings += $sId
    }
}
Assert-Test "All hero_heravyn settings exist in sections/hero.liquid schema" ($heroInvalidSettings.Count -eq 0) "Unknown settings: $($heroInvalidSettings -join ', ')"

Assert-Test "hero blocks includes hero_heading" ($heroSec.blocks.hero_heading -ne $null) "hero_heading missing"
Assert-Test "hero_heading text contains 'STRONGER YOU.'" ($heroSec.blocks.hero_heading.settings.text -match "STRONGER YOU\.") "Tagline missing"
Assert-Test "hero_heading type_preset is 'h1'" ($heroSec.blocks.hero_heading.settings.type_preset -eq "h1") "type_preset is '$($heroSec.blocks.hero_heading.settings.type_preset)'"
Assert-Test "hero blocks includes hero_subcopy" ($heroSec.blocks.hero_subcopy -ne $null) "hero_subcopy missing"
Assert-Test "hero_subcopy type_preset is 'rte'" ($heroSec.blocks.hero_subcopy.settings.type_preset -eq "rte") "type_preset is '$($heroSec.blocks.hero_subcopy.settings.type_preset)'"
Assert-Test "hero blocks includes hero_cta_group" ($heroSec.blocks.hero_cta_group -ne $null) "hero_cta_group missing"

$ctaAll = $heroSec.blocks.hero_cta_group.blocks.cta_all
$ctaPilates = $heroSec.blocks.hero_cta_group.blocks.cta_pilates
Assert-Test "CTA 1 exists with label 'Shop All Equipment'" ($ctaAll.settings.label -eq "Shop All Equipment") "CTA 1 label is '$($ctaAll.settings.label)'"
Assert-Test "CTA 1 links to 'shopify://collections/all'" ($ctaAll.settings.link -eq "shopify://collections/all") "CTA 1 link is '$($ctaAll.settings.link)'"
Assert-Test "CTA 1 uses Dusty Rose token" ($ctaAll.settings.custom_button_background -match "settings\.color_palette\.color1") "CTA 1 background is '$($ctaAll.settings.custom_button_background)'"

Assert-Test "CTA 2 exists with label 'Explore Pilates & Glutes'" ($ctaPilates.settings.label -eq "Explore Pilates & Glutes") "CTA 2 label is '$($ctaPilates.settings.label)'"
Assert-Test "CTA 2 links to 'shopify://collections/pilates-glutes'" ($ctaPilates.settings.link -eq "shopify://collections/pilates-glutes") "CTA 2 link is '$($ctaPilates.settings.link)'"

# --- SECTION 2: shop_by_category (sections/section.liquid) ---
Write-Host "`n  [Section: shop_by_category]" -ForegroundColor Cyan
$catSec = $sections.shop_by_category
$sectionSchema = Get-LiquidSchema (Join-Path $ProjectRoot "sections\section.liquid")
Assert-Test "section.liquid schema parsed successfully" ($sectionSchema -ne $null) "section.liquid schema null"
Assert-Test "shop_by_category type is 'section'" ($catSec.type -eq "section") "type is '$($catSec.type)'"

$secInvalidSettings = @()
foreach ($prop in $catSec.settings.PSObject.Properties) {
    $sId = $prop.Name
    if (-not (Test-SchemaSetting $sectionSchema $sId)) {
        $secInvalidSettings += $sId
    }
}
Assert-Test "All shop_by_category settings exist in sections/section.liquid schema" ($secInvalidSettings.Count -eq 0) "Unknown settings: $($secInvalidSettings -join ', ')"
Assert-Test "shop_by_category uses Soft Beige background token" ($catSec.settings.background_color -match "settings\.color_palette\.color2") "background_color is '$($catSec.settings.background_color)'"

$catGrid = $catSec.blocks.category_grid.blocks
Assert-Test "Category card 1 (Strength) exists and links to shopify://collections/strength" ($catGrid.card_strength -ne $null -and $catGrid.card_strength.settings.link -eq "shopify://collections/strength") ""
Assert-Test "Category card 1 copy mentions strength equipment" ($catGrid.card_strength.blocks.t1_sub.settings.text -match "Dumbbells.*kettlebells") ""

Assert-Test "Category card 2 (Pilates & Glutes) exists and links to shopify://collections/pilates-glutes" ($catGrid.card_pilates -ne $null -and $catGrid.card_pilates.settings.link -eq "shopify://collections/pilates-glutes") ""
Assert-Test "Category card 2 copy mentions pilates equipment" ($catGrid.card_pilates.blocks.t2_sub.settings.text -match "Resistance bands.*ankle weights") ""

Assert-Test "Category card 3 (Home Workouts) exists and links to shopify://collections/home-workouts" ($catGrid.card_homeworkouts -ne $null -and $catGrid.card_homeworkouts.settings.link -eq "shopify://collections/home-workouts") ""
Assert-Test "Category card 3 copy mentions home workout equipment" ($catGrid.card_homeworkouts.blocks.t3_sub.settings.text -match "Compact benches.*pull-up") ""

Assert-Test "Category card 4 (Recovery) exists and links to shopify://collections/recovery" ($catGrid.card_recovery -ne $null -and $catGrid.card_recovery.settings.link -eq "shopify://collections/recovery") ""
Assert-Test "Category card 4 copy mentions recovery equipment" ($catGrid.card_recovery.blocks.t4_sub.settings.text -match "Foam rollers.*massage balls") ""

# --- SECTION 3: product_list_fa6P9H (sections/product-list.liquid) ---
Write-Host "`n  [Section: product_list_fa6P9H]" -ForegroundColor Cyan
$plistSec = $sections.product_list_fa6P9H
$plistSchema = Get-LiquidSchema (Join-Path $ProjectRoot "sections\product-list.liquid")
Assert-Test "product-list.liquid schema parsed successfully" ($plistSchema -ne $null) "product-list.liquid schema null"
Assert-Test "product_list_fa6P9H type is 'product-list'" ($plistSec.type -eq "product-list") "type is '$($plistSec.type)'"

$plistInvalidSettings = @()
foreach ($prop in $plistSec.settings.PSObject.Properties) {
    $sId = $prop.Name
    if (-not (Test-SchemaSetting $plistSchema $sId)) {
        $plistInvalidSettings += $sId
    }
}
Assert-Test "All product_list_fa6P9H settings exist in sections/product-list.liquid schema" ($plistInvalidSettings.Count -eq 0) "Unknown settings: $($plistInvalidSettings -join ', ')"

$staticHeader = $plistSec.blocks.'static-header'
$staticCard = $plistSec.blocks.'static-product-card'
Assert-Test "Static block 'static-header' exists" ($staticHeader -ne $null) "static-header missing"
Assert-Test "static-header has static: true" ($staticHeader.static -eq $true) "static-header static is not true"
Assert-Test "static-header type is '_product-list-content'" ($staticHeader.type -eq "_product-list-content") "static-header type is '$($staticHeader.type)'"

Assert-Test "Static block 'static-product-card' exists" ($staticCard -ne $null) "static-product-card missing"
Assert-Test "static-product-card has static: true" ($staticCard.static -eq $true) "static-product-card static is not true"
Assert-Test "static-product-card type is '_product-card'" ($staticCard.type -eq "_product-card") "static-product-card type is '$($staticCard.type)'"

Assert-Test "Product list grid columns is 4" ($plistSec.settings.columns -eq 4) "columns is $($plistSec.settings.columns)"
Assert-Test "Product list max_products is 8" ($plistSec.settings.max_products -eq 8) "max_products is $($plistSec.settings.max_products)"
Assert-Test "Product list collection is 'all'" ($plistSec.settings.collection -eq "all") "collection is '$($plistSec.settings.collection)'"

$cardSubBlocks = $staticCard.blocks
Assert-Test "Product card includes _product-card-gallery" ($cardSubBlocks.product_card_gallery_677WP3 -ne $null -and $cardSubBlocks.product_card_gallery_677WP3.type -eq "_product-card-gallery") ""
Assert-Test "Product card includes product-title" ($cardSubBlocks.product_title_YXxMTj -ne $null -and $cardSubBlocks.product_title_YXxMTj.type -eq "product-title") ""
Assert-Test "Product card includes price" ($cardSubBlocks.price_JQzVV4 -ne $null -and $cardSubBlocks.price_JQzVV4.type -eq "price") ""

# --- SECTION 4: brand_story_heravyn (sections/media-with-content.liquid) ---
Write-Host "`n  [Section: brand_story_heravyn]" -ForegroundColor Cyan
$storySec = $sections.brand_story_heravyn
$mwcSchema = Get-LiquidSchema (Join-Path $ProjectRoot "sections\media-with-content.liquid")
Assert-Test "media-with-content.liquid schema parsed successfully" ($mwcSchema -ne $null) "media-with-content.liquid schema null"
Assert-Test "brand_story_heravyn type is 'media-with-content'" ($storySec.type -eq "media-with-content") "type is '$($storySec.type)'"

$storyInvalidSettings = @()
foreach ($prop in $storySec.settings.PSObject.Properties) {
    $sId = $prop.Name
    if (-not (Test-SchemaSetting $mwcSchema $sId)) {
        $storyInvalidSettings += $sId
    }
}
Assert-Test "All brand_story_heravyn settings exist in sections/media-with-content.liquid schema" ($storyInvalidSettings.Count -eq 0) "Unknown settings: $($storyInvalidSettings -join ', ')"

$mediaBlock = $storySec.blocks.media
$contentBlock = $storySec.blocks.content
Assert-Test "Static block 'media' exists" ($mediaBlock -ne $null) "media block missing"
Assert-Test "media block has static: true" ($mediaBlock.static -eq $true) "media static is not true"
Assert-Test "media block type is '_media-without-appearance'" ($mediaBlock.type -eq "_media-without-appearance") "media type is '$($mediaBlock.type)'"

Assert-Test "Static block 'content' exists" ($contentBlock -ne $null) "content block missing"
Assert-Test "content block has static: true" ($contentBlock.static -eq $true) "content static is not true"
Assert-Test "content block type is '_content-without-appearance'" ($contentBlock.type -eq "_content-without-appearance") "content type is '$($contentBlock.type)'"

$storySubBlocks = $contentBlock.blocks
Assert-Test "Brand story caption exists ('THE HERAVYN PHILOSOPHY')" ($storySubBlocks.story_caption.settings.text -match "THE HERAVYN PHILOSOPHY") ""
Assert-Test "Brand story heading communicates mission" ($storySubBlocks.story_group.blocks.story_heading.settings.text -match "Empowering Women Through Functional Strength") ""
Assert-Test "Brand story CTA is 'Read Our Story' to shopify://pages/about" ($storySubBlocks.story_button.settings.label -eq "Read Our Story" -and $storySubBlocks.story_button.settings.link -eq "shopify://pages/about") ""
Assert-Test "Brand story CTA uses Dusty Rose token" ($storySubBlocks.story_button.settings.custom_button_background -match "settings\.color_palette\.color1") ""

# --- SECTION 5: newsletter_social_section (sections/section.liquid) ---
Write-Host "`n  [Section: newsletter_social_section]" -ForegroundColor Cyan
$nlSec = $sections.newsletter_social_section
Assert-Test "newsletter_social_section type is 'section'" ($nlSec.type -eq "section") "type is '$($nlSec.type)'"

$nlInvalidSettings = @()
foreach ($prop in $nlSec.settings.PSObject.Properties) {
    $sId = $prop.Name
    if (-not (Test-SchemaSetting $sectionSchema $sId)) {
        $nlInvalidSettings += $sId
    }
}
Assert-Test "All newsletter_social_section settings exist in sections/section.liquid schema" ($nlInvalidSettings.Count -eq 0) "Unknown settings: $($nlInvalidSettings -join ', ')"
Assert-Test "newsletter_social_section uses Soft Beige background token" ($nlSec.settings.background_color -match "settings\.color_palette\.color2") ""
Assert-Test "newsletter_social_section has rounded card corners (border_radius: 16)" ($nlSec.settings.border_radius -eq 16) ""

$emailBlock = $nlSec.blocks.nl_form
$emailSchema = Get-LiquidSchema (Join-Path $ProjectRoot "blocks\email-signup.liquid")
Assert-Test "email-signup.liquid schema parsed successfully" ($emailSchema -ne $null) "email-signup schema null"
Assert-Test "nl_form block type is 'email-signup'" ($emailBlock.type -eq "email-signup") ""

$emailInvalidSettings = @()
$emailAdvisorySettings = @()
$sizeStyleSettings = @('width', 'custom_width', 'height', 'custom_height', 'width_mobile', 'custom_width_mobile')
foreach ($prop in $emailBlock.settings.PSObject.Properties) {
    $sId = $prop.Name
    if (-not (Test-SchemaSetting $emailSchema $sId)) {
        if ($sizeStyleSettings -contains $sId) {
            $emailAdvisorySettings += $sId
        } else {
            $emailInvalidSettings += $sId
        }
    }
}
Assert-Test "All email-signup block settings are schema-declared or handled by snippets/size-style.liquid" ($emailInvalidSettings.Count -eq 0) "Unknown settings: $($emailInvalidSettings -join ', ')"
if ($emailAdvisorySettings.Count -gt 0) {
    Write-Host "    [ADVISORY] email-signup settings not in schema but rendered by size-style.liquid: $($emailAdvisorySettings -join ', ')" -ForegroundColor Yellow
}

Assert-Test "Email signup has pill border radius (100)" ($emailBlock.settings.border_radius -eq 100) "border_radius is $($emailBlock.settings.border_radius)"
Assert-Test "Email signup CTA uses Dusty Rose token" ($emailBlock.settings.custom_button_background -match "settings\.color_palette\.color1") ""
Assert-Test "Email signup input uses Warm Ivory background token" ($emailBlock.settings.input_background_color -match "settings\.color_palette\.background") ""

$socialBlock = $nlSec.blocks.nl_socials
$socialSchema = Get-LiquidSchema (Join-Path $ProjectRoot "blocks\social-links.liquid")
Assert-Test "social-links.liquid schema parsed successfully" ($socialSchema -ne $null) "social-links schema null"
Assert-Test "nl_socials block type is 'social-links'" ($socialBlock.type -eq "social-links") ""

$socialInvalidSettings = @()
foreach ($prop in $socialBlock.settings.PSObject.Properties) {
    $sId = $prop.Name
    if (-not (Test-SchemaSetting $socialSchema $sId)) {
        $socialInvalidSettings += $sId
    }
}
Assert-Test "All social-links block settings exist in blocks/social-links.liquid schema" ($socialInvalidSettings.Count -eq 0) "Unknown settings: $($socialInvalidSettings -join ', ')"
Assert-Test "Social channels configured: Instagram, TikTok, YouTube, Facebook" (
    $socialBlock.settings.instagram_url -match "instagram\.com/heravyn" -and
    $socialBlock.settings.tiktok_url -match "tiktok\.com/@heravyn" -and
    $socialBlock.settings.youtube_url -match "youtube\.com/@heravyn" -and
    $socialBlock.settings.facebook_url -match "facebook\.com/heravyn"
) ""

Write-Host "`n  [Full Theme Block Hierarchy Schema Verification]" -ForegroundColor Cyan
function Validate-BlockTreeRobust($blocksObj, $path) {
    $errors = @()
    if ($null -eq $blocksObj) { return $errors }
    foreach ($prop in $blocksObj.PSObject.Properties) {
        $blockId = $prop.Name
        $block = $prop.Value
        $blockType = $block.type
        $schema = Get-BlockSchemaCached $blockType
        if ($null -eq $schema) {
            $errors += "Schema not found for block type '$blockType' at $path/$blockId"
        } else {
            if ($block.settings -ne $null) {
                foreach ($sprop in $block.settings.PSObject.Properties) {
                    $settingId = $sprop.Name
                    if (-not (Test-SchemaSetting $schema $settingId)) {
                        # Check if setting is a known size-style or spacing-style snippet setting
                        $isSnippetSetting = $false
                        if ($sizeStyleSettings -contains $settingId) {
                            $blockFile = Join-Path $ProjectRoot "blocks\$blockType.liquid"
                            if (Test-Path $blockFile) {
                                $blockText = [System.IO.File]::ReadAllText($blockFile)
                                if ($blockText -match "render\s+['""]size-style['""]") {
                                    $isSnippetSetting = $true
                                }
                            }
                        }
                        if (-not $isSnippetSetting) {
                            $errors += "Unknown setting '$settingId' on block '$blockId' (type: '$blockType') at $path/$blockId"
                        }
                    }
                }
            }
        }
        if ($block.blocks -ne $null) {
            $errors += Validate-BlockTreeRobust $block.blocks "$path/$blockId"
        }
    }
    return $errors
}

$allBlockTreeErrors = @()
foreach ($secProp in $sections.PSObject.Properties) {
    $secName = $secProp.Name
    $secObj = $secProp.Value
    if ($secObj.blocks -ne $null) {
        $allBlockTreeErrors += Validate-BlockTreeRobust $secObj.blocks $secName
    }
}
Assert-Test "All blocks in templates/index.json conform to block schemas and snippet dependencies" ($allBlockTreeErrors.Count -eq 0) "Block schema errors: $($allBlockTreeErrors -join '; ')"
if ($allBlockTreeErrors.Count -gt 0) {
    foreach ($err in $allBlockTreeErrors) {
        Write-Host "    $err" -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------------------------
# 4. Global Block ID Integrity & Static Block Invariants
# ------------------------------------------------------------------------------
Write-Host "`n--- 4. Global Block ID Integrity & Static Block Invariants ---" -ForegroundColor Yellow

$plistContent = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "sections\product-list.liquid"), [System.Text.Encoding]::UTF8)
$hasHeaderIdInLiquid = $plistContent -match "id:\s*['""]static-header['""]"
$hasCardIdInLiquid = $plistContent -match "id:\s*['""]static-product-card['""]"
Assert-Test "product-list.liquid template references id: 'static-header'" $hasHeaderIdInLiquid ""
Assert-Test "product-list.liquid template references id: 'static-product-card'" $hasCardIdInLiquid ""

$mwcContent = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "sections\media-with-content.liquid"), [System.Text.Encoding]::UTF8)
$hasMediaIdInLiquid = $mwcContent -match "id:\s*['""]media['""]"
$hasContentIdInLiquid = $mwcContent -match "id:\s*['""]content['""]"
Assert-Test "media-with-content.liquid template references id: 'media'" $hasMediaIdInLiquid ""
Assert-Test "media-with-content.liquid template references id: 'content'" $hasContentIdInLiquid ""

function Check-BlockIds($obj, $path) {
    $invalidIds = @()
    if ($obj.blocks -ne $null) {
        foreach ($prop in $obj.blocks.PSObject.Properties) {
            $id = $prop.Name
            if ($id -notmatch '^[a-zA-Z0-9_\-]+$') {
                $invalidIds += "$path/$id"
            }
            $child = $prop.Value
            if ($child.blocks -ne $null) {
                $invalidIds += Check-BlockIds $child "$path/$id"
            }
        }
    }
    return $invalidIds
}

$allInvalidBlockIds = @()
foreach ($secProp in $sections.PSObject.Properties) {
    $secName = $secProp.Name
    $secObj = $secProp.Value
    $allInvalidBlockIds += Check-BlockIds $secObj $secName
}
Assert-Test "All Theme Block IDs adhere to alphanumeric/hyphen/underscore naming format" ($allInvalidBlockIds.Count -eq 0) "Invalid block IDs: $($allInvalidBlockIds -join ', ')"

# ------------------------------------------------------------------------------
# 5. Summary & Verdict
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Total checks: $TotalChecks | Passed: $PassedChecks | Failed: $FailedChecks" -ForegroundColor Cyan
if ($FailedChecks -eq 0) {
    Write-Host "VERDICT: ALL ADVERSARIAL CHALLENGES PASSED [APPROVE]" -ForegroundColor Green
} else {
    Write-Host "VERDICT: CHALLENGES FAILED [REQUEST_CHANGES]" -ForegroundColor Red
    Write-Host "Failures summary:" -ForegroundColor Red
    foreach ($issue in $Issues) {
        Write-Host "  $issue" -ForegroundColor Red
    }
}
Write-Host "======================================================================" -ForegroundColor Cyan

if ($FailedChecks -gt 0) {
    exit 1
}
exit 0
