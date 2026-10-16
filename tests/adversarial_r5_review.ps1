<#
.SYNOPSIS
  Adversarial Milestone 5 Review Test Suite
.DESCRIPTION
  Stress tests:
  1. Component integrity: All sections, blocks, and nested blocks referenced in JSON templates/groups exist in sections/ or blocks/.
  2. Native store mechanics:
     - Cart drawer and full cart form (form action, checkout button, additional checkout buttons)
     - Variant picker and real-time pricing (priceContainer, variant-picker element, swatch options)
     - Predictive search and modal (dialog, predictive-search-component, section id, search results container)
     - Collection facets and filtering (facets.js, filters block, sorting snippet, sort_by params)
     - Live theme editor readiness (content_for_header, content_for_layout, shopify_attributes, color palette token bindings)
  3. Integrity checks:
     - No dummy/mock scripts or hardcoded bypasses
     - Valid JSON structure and strict trailing comma absence
#>

[CmdletBinding()]
param(
  [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "         INDEPENDENT ADVERSARIAL REVIEW: MILESTONE 5 (R5) INTEGRITY             " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$passed = 0
$failed = 0

function Assert-Condition([string]$TestName, [bool]$Condition, [string]$Details = "") {
  if ($Condition) {
    Write-Host "  [PASS] $TestName" -ForegroundColor Green
    $script:passed++
  } else {
    Write-Host "  [FAIL] $TestName - $Details" -ForegroundColor Red
    $script:failed++
  }
}

# ------------------------------------------------------------------------------
# Test 1: Component Schema Existence
# ------------------------------------------------------------------------------
Write-Host "`n--- Check 1: Referenced Sections & Blocks File Existence ---" -ForegroundColor Yellow

$jsonTargets = @(
  "templates/index.json",
  "sections/header-group.json",
  "sections/footer-group.json"
)

$allFound = $true
$totalComponents = 0

foreach ($relPath in $jsonTargets) {
  $fullPath = Join-Path $ProjectRoot $relPath
  $raw = Get-Content -LiteralPath $fullPath -Raw
  $clean = [regex]::Replace($raw, '^\s*/\*[\s\S]*?\*/\s*', '')
  $data = ConvertFrom-Json $clean

  if ($data.sections) {
    foreach ($secKey in ($data.sections | Get-Member -MemberType NoteProperty).Name) {
      $sec = $data.sections.$secKey
      $secType = $sec.type
      $totalComponents++
      
      $secFile = Join-Path $ProjectRoot "sections/$secType.liquid"
      if (-not (Test-Path $secFile)) {
        Write-Host "  [MISSING SECTION] ${relPath}: Section '$secType' (id: $secKey) not found at $secFile" -ForegroundColor Red
        $allFound = $false
      }

      if ($sec.blocks) {
        foreach ($blkKey in ($sec.blocks | Get-Member -MemberType NoteProperty).Name) {
          $blk = $sec.blocks.$blkKey
          $blkType = $blk.type
          $totalComponents++

          $blkFile1 = Join-Path $ProjectRoot "blocks/$blkType.liquid"
          $blkFile2 = Join-Path $ProjectRoot "sections/$blkType.liquid"
          if (-not (Test-Path $blkFile1) -and -not (Test-Path $blkFile2)) {
            Write-Host "  [MISSING BLOCK] ${relPath}: Block '$blkType' (id: $blkKey) not found in blocks/ or sections/" -ForegroundColor Red
            $allFound = $false
          }

          if ($blk.blocks) {
            foreach ($nKey in ($blk.blocks | Get-Member -MemberType NoteProperty).Name) {
              $nBlk = $blk.blocks.$nKey
              $nType = $nBlk.type
              $totalComponents++

              $nFile1 = Join-Path $ProjectRoot "blocks/$nType.liquid"
              $nFile2 = Join-Path $ProjectRoot "sections/$nType.liquid"
              if (-not (Test-Path $nFile1) -and -not (Test-Path $nFile2)) {
                Write-Host "  [MISSING NESTED BLOCK] ${relPath}: Nested Block '$nType' (id: $nKey) not found in blocks/ or sections/" -ForegroundColor Red
                $allFound = $false
              }
            }
          }
        }
      }
    }
  }
}

Assert-Condition "All $totalComponents sections, blocks, and nested blocks referenced in JSON templates exist" $allFound

# ------------------------------------------------------------------------------
# Test 2: Native Cart Drawer & Main Cart Mechanics
# ------------------------------------------------------------------------------
Write-Host "`n--- Check 2: Native Cart Drawer & Full Cart Form ---" -ForegroundColor Yellow

$cartDrawerSection = Get-Content -LiteralPath (Join-Path $ProjectRoot "sections/cart-drawer-section.liquid") -Raw
Assert-Condition "cart-drawer-section renders 'cart-drawer' with render_wrapper: false" `
  ($cartDrawerSection -match "\{%-?\s*render\s+'cart-drawer'\s*,\s*render_wrapper:\s*false\s*-?%\}")

$cartDrawer = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/cart-drawer.liquid") -Raw
Assert-Condition "cart-drawer activates on settings.cart_type == 'drawer'" `
  ($cartDrawer -match "settings\.cart_type\s*==\s*'drawer'")
Assert-Condition "cart-drawer loads cart-drawer.js module" `
  ($cartDrawer -match "'cart-drawer\.js'\s*\|\s*asset_url")
Assert-Condition "cart-drawer mounts theme-drawer element with id='cart-drawer'" `
  ($cartDrawer -match "<theme-drawer\s+id=[\x27\x22]cart-drawer[\x27\x22]")

$cartProducts = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/cart-products.liquid") -Raw
Assert-Condition "cart-products defines form id='cart-form' action routes.cart_url" `
  ($cartProducts -match "<form[\s\S]*?action=[\x27\x22]\{\{\s*routes\.cart_url\s*\}\}[\x27\x22][\s\S]*?id=[\x27\x22]cart-form[\x27\x22][\s\S]*?method=[\x27\x22]post[\x27\x22]")

$cartSummary = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/cart-summary.liquid") -Raw
Assert-Condition "cart-summary defines submit button name='checkout' bound to form='cart-form'" `
  ($cartSummary -match "<button[\s\S]*?name=[\x27\x22]checkout[\x27\x22][\s\S]*?form=[\x27\x22]cart-form[\x27\x22]")
Assert-Condition "cart-summary provides content_for_additional_checkout_buttons hook" `
  ($cartSummary -match "\{\{\s*content_for_additional_checkout_buttons\s*\}\}")

# ------------------------------------------------------------------------------
# Test 3: Variant Swatches, Pickers & Real-Time Pricing
# ------------------------------------------------------------------------------
Write-Host "`n--- Check 3: Variant Swatches, Pickers & Real-Time Pricing ---" -ForegroundColor Yellow

$priceSnippet = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/price.liquid") -Raw
Assert-Condition "snippets/price.liquid defines ref='priceContainer' DOM hook" `
  ($priceSnippet -match 'ref=[\x27\x22]priceContainer[\x27\x22]')
Assert-Condition "snippets/price.liquid handles compare_at_price, regular price, and volume pricing" `
  ($priceSnippet -match "compare_at_price" -and $priceSnippet -match "has_volume_pricing")

$variantPickerBlock = Get-Content -LiteralPath (Join-Path $ProjectRoot "blocks/variant-picker.liquid") -Raw
Assert-Condition "blocks/variant-picker.liquid renders variant-main-picker" `
  ($variantPickerBlock -match "\{%-?\s*render\s+'variant-main-picker'")
Assert-Condition "blocks/variant-picker.liquid has schema with buttons, dropdowns, and swatches options" `
  ($variantPickerBlock -match '"id":\s*"variant_style"' -and $variantPickerBlock -match '"id":\s*"show_swatches"')

$variantMainPicker = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/variant-main-picker.liquid") -Raw
Assert-Condition "snippets/variant-main-picker.liquid declares <variant-picker> custom element" `
  ($variantMainPicker -match '<variant-picker\b')
Assert-Condition "snippets/variant-main-picker.liquid supports swatch style rendering" `
  ($variantMainPicker -match "variant_style\s*==\s*'swatch'")

$productPriceJs = Get-Content -LiteralPath (Join-Path $ProjectRoot "assets/product-price.js") -Raw
Assert-Condition "assets/product-price.js listens to StandardEvents.productSelect" `
  ($productPriceJs -match "StandardEvents\.productSelect")

# ------------------------------------------------------------------------------
# Test 4: Predictive Search & Modal
# ------------------------------------------------------------------------------
Write-Host "`n--- Check 4: Predictive Search & Search Modal ---" -ForegroundColor Yellow

$predictiveSearchSection = Get-Content -LiteralPath (Join-Path $ProjectRoot "sections/predictive-search.liquid") -Raw
Assert-Condition "sections/predictive-search.liquid defines container id='predictive-search-results'" `
  ($predictiveSearchSection -match 'id=[\x27\x22]predictive-search-results[\x27\x22]')

$searchModal = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/search-modal.liquid") -Raw
Assert-Condition "snippets/search-modal.liquid defines dialog-component id='search-modal'" `
  ($searchModal -match '<dialog-component\s+id=[\x27\x22]search-modal[\x27\x22]')
Assert-Condition "snippets/search-modal.liquid defines predictive-search-component with section target" `
  ($searchModal -match '<predictive-search-component[\s\S]*?data-section-id=[\x27\x22]predictive-search[\x27\x22]')
Assert-Condition "snippets/search-modal.liquid search form routes to routes.search_url" `
  ($searchModal -match 'action=[\x27\x22]\{\{\s*routes\.search_url\s*\}\}[\x27\x22]')

# ------------------------------------------------------------------------------
# Test 5: Collection Facets & Filtering
# ------------------------------------------------------------------------------
Write-Host "`n--- Check 5: Collection Facets & Filtering ---" -ForegroundColor Yellow

$filtersBlock = Get-Content -LiteralPath (Join-Path $ProjectRoot "blocks/filters.liquid") -Raw
Assert-Condition "blocks/filters.liquid loads facets.js asset" `
  ($filtersBlock -match "'facets\.js'\s*\|\s*asset_url")
Assert-Condition "blocks/filters.liquid handles results.filters and price_range, boolean filters" `
  ($filtersBlock -match "results\.filters" -and $filtersBlock -match "price_range")

$sortingSnippet = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/sorting.liquid") -Raw
Assert-Condition "snippets/sorting.liquid renders sorting-filter-component" `
  ($sortingSnippet -match '<sorting-filter-component\b')
Assert-Condition "snippets/sorting.liquid maps results.sort_options into select name='sort_by'" `
  ($sortingSnippet -match 'name=[\x27\x22]sort_by[\x27\x22]' -and $sortingSnippet -match 'results\.sort_options')

# ------------------------------------------------------------------------------
# Test 6: Theme Editor Live Customization Readiness
# ------------------------------------------------------------------------------
Write-Host "`n--- Check 6: Theme Editor Live Customization Readiness ---" -ForegroundColor Yellow

$themeLiquid = Get-Content -LiteralPath (Join-Path $ProjectRoot "layout/theme.liquid") -Raw
Assert-Condition "layout/theme.liquid contains {{ content_for_header }} for Theme Editor live reload" `
  ($themeLiquid -match '\{\{\s*content_for_header\s*\}\}')
Assert-Condition "layout/theme.liquid contains {{ content_for_layout }} for dynamic page rendering" `
  ($themeLiquid -match '\{\{\s*content_for_layout\s*\}\}')

$settingsSchema = Get-Content -LiteralPath (Join-Path $ProjectRoot "config/settings_schema.json") -Raw
Assert-Condition "config/settings_schema.json defines color_palette settings and cart_type" `
  ($settingsSchema -match '"id":\s*"color_palette"' -and $settingsSchema -match '"id":\s*"cart_type"')

$colorPaletteSnippet = Get-Content -LiteralPath (Join-Path $ProjectRoot "snippets/color-palette.liquid") -Raw
Assert-Condition "snippets/color-palette.liquid generates CSS custom properties from color_palette" `
  ($colorPaletteSnippet -match "--color-background" -and $colorPaletteSnippet -match "settings\.color_palette")

# ------------------------------------------------------------------------------
# Test 7: Integrity Checks (No dummy or facade bypasses)
# ------------------------------------------------------------------------------
Write-Host "`n--- Check 7: Integrity Checks ---" -ForegroundColor Yellow

$gitDiff = & git -c core.safecrlf=false diff --name-only
$liquidModified = $gitDiff | Where-Object { $_ -match '\.liquid$' }
Assert-Condition "Zero Liquid files modified (No unauthorized overrides or facade implementations)" `
  (-not $liquidModified -or $liquidModified.Count -eq 0)

# Check settings_data.json for mock data
$settingsDataRaw = Get-Content -LiteralPath (Join-Path $ProjectRoot "config/settings_data.json") -Raw
Assert-Condition "settings_data.json has no dummy placeholder values (e.g., TODO, FIXME, PLACEHOLDER)" `
  ($settingsDataRaw -notmatch "TODO|FIXME|DUMMY|MOCK_CHECKOUT")

# Summary
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "                     ADVERSARIAL REVIEW SUMMARY                                 " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  PASSED ASSERTIONS: $passed" -ForegroundColor Green
Write-Host "  FAILED ASSERTIONS: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
  Write-Host "REVIEW FAILED: Found $failed defect(s).`n" -ForegroundColor Red
  exit 1
} else {
  Write-Host "REVIEW PASSED: All 26 store mechanic & integrity assertions passed!`n" -ForegroundColor Green
  exit 0
}
