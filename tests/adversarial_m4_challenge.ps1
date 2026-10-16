# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 4 Adversarial Challenge Suite
# Reviewer: reviewer_m4_2 (Reviewer & Critic)
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
Write-Host "Milestone 4 Adversarial Challenge Verification Suite" -ForegroundColor Cyan
Write-Host "Target: sections/footer-group.json" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$FooterJsonPath = Join-Path $ProjectRoot "sections\footer-group.json"
Assert-Test "File exists: sections/footer-group.json" (Test-Path $FooterJsonPath) "File not found"

if (-not (Test-Path $FooterJsonPath)) {
    Write-Host "Cannot proceed without sections/footer-group.json" -ForegroundColor Red
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
Assert-Test "Shopify standard comment header is present and valid" ($commentMatch.Success) "Comment header missing or malformed"

$bodyText = if ($commentMatch.Success) {
    $rawText.Substring($commentMatch.Index + $commentMatch.Length).Trim()
} else {
    $rawText.Trim()
}

# Parser 1: PowerShell ConvertFrom-Json
$parsedPS = $null
try {
    $parsedPS = $bodyText | ConvertFrom-Json
    Assert-Test "PowerShell ConvertFrom-Json deserialization" ($null -ne $parsedPS)
} catch {
    Assert-Test "PowerShell ConvertFrom-Json deserialization" $false $_.Exception.Message
}

# Parser 2: .NET JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
try {
    $netParsed = $jsSerializer.DeserializeObject($bodyText)
    Assert-Test ".NET JavaScriptSerializer deserialization" ($null -ne $netParsed)
} catch {
    Assert-Test ".NET JavaScriptSerializer deserialization" $false $_.Exception.Message
}

# Parser 3: Strict JsonReaderWriterFactory
Add-Type -AssemblyName System.Runtime.Serialization
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyText)
    $quotas = [System.Xml.XmlDictionaryReaderQuotas]::Max
    $jsonReader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($bytes, 0, $bytes.Length, [System.Text.Encoding]::UTF8, $quotas, $null)
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.Load($jsonReader)
    Assert-Test "Strict JsonReaderWriterFactory XML bridge deserialization" ($null -ne $xmlDoc.DocumentElement)
} catch {
    Assert-Test "Strict JsonReaderWriterFactory XML bridge deserialization" $false $_.Exception.Message
}

# Trailing Comma Analysis
$lines = $bodyText -split '\r?\n'
$hasTrailing = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()
    if ($line -match ',$' -and ($i + 1 -lt $lines.Length)) {
        $nextLine = $lines[$i + 1].Trim()
        if ($nextLine -match '^\s*[}\]]') {
            $hasTrailing = $true
            break
        }
    }
}
Assert-Test "Zero trailing commas detected" (-not $hasTrailing) "Found trailing comma before closing brace/bracket"

# ------------------------------------------------------------------------------
# 2. Strict Bijectivity Across All Levels
# ------------------------------------------------------------------------------
Write-Host "`n--- 2. Strict Bijectivity Across All Hierarchy Levels ---" -ForegroundColor Yellow

# Root sections bijectivity
$rootSecKeys = @($parsedPS.sections.psobject.Properties | ForEach-Object { $_.Name })
$rootOrder = @($parsedPS.order)
$rootKeysSorted = ($rootSecKeys | Sort-Object) -join ","
$rootOrderSorted = ($rootOrder | Sort-Object) -join ","
Assert-Test "Root level bijectivity (sections keys match order array)" ($rootKeysSorted -eq $rootOrderSorted -and $rootSecKeys.Count -eq $rootOrder.Count) "Keys: $rootKeysSorted vs Order: $rootOrderSorted"

# Footer section block bijectivity
$footerBlocks = @($parsedPS.sections.footer.blocks.psobject.Properties | ForEach-Object { $_.Name })
$footerOrder = @($parsedPS.sections.footer.block_order)
$footerBlocksSorted = ($footerBlocks | Sort-Object) -join ","
$footerOrderSorted = ($footerOrder | Sort-Object) -join ","
Assert-Test "Footer section bijectivity (blocks keys match block_order)" ($footerBlocksSorted -eq $footerOrderSorted -and $footerBlocks.Count -eq $footerOrder.Count) "Blocks: $footerBlocksSorted vs Order: $footerOrderSorted"

# Group newsletter nested block bijectivity
$gnBlocks = @($parsedPS.sections.footer.blocks.group_newsletter.blocks.psobject.Properties | ForEach-Object { $_.Name })
$gnOrder = @($parsedPS.sections.footer.blocks.group_newsletter.block_order)
$gnBlocksSorted = ($gnBlocks | Sort-Object) -join ","
$gnOrderSorted = ($gnOrder | Sort-Object) -join ","
Assert-Test "Newsletter group nested bijectivity (blocks keys match block_order)" ($gnBlocksSorted -eq $gnOrderSorted -and $gnBlocks.Count -eq $gnOrder.Count) "Blocks: $gnBlocksSorted vs Order: $gnOrderSorted"

# Utilities section block bijectivity
$utilBlocks = @($parsedPS.sections.utilities.blocks.psobject.Properties | ForEach-Object { $_.Name })
$utilOrder = @($parsedPS.sections.utilities.block_order)
$utilBlocksSorted = ($utilBlocks | Sort-Object) -join ","
$utilOrderSorted = ($utilOrder | Sort-Object) -join ","
Assert-Test "Utilities section bijectivity (blocks keys match block_order)" ($utilBlocksSorted -eq $utilOrderSorted -and $utilBlocks.Count -eq $utilOrder.Count) "Blocks: $utilBlocksSorted vs Order: $utilOrderSorted"

# ------------------------------------------------------------------------------
# 3. File System Theme Blocks Resolution & Schema Validation
# ------------------------------------------------------------------------------
Write-Host "`n--- 3. File System Theme Blocks Resolution & Schema Validation ---" -ForegroundColor Yellow

# Check sections exist
$footerLiquid = Join-Path $ProjectRoot "sections\footer.liquid"
$utilLiquid = Join-Path $ProjectRoot "sections\footer-utilities.liquid"
Assert-Test "sections/footer.liquid exists on filesystem" (Test-Path $footerLiquid)
Assert-Test "sections/footer-utilities.liquid exists on filesystem" (Test-Path $utilLiquid)

# Check all block types exist in blocks/
$requiredBlocks = @(
    "group",
    "text",
    "email-signup",
    "menu",
    "payment-icons",
    "footer-copyright",
    "footer-policy-list",
    "social-links"
)

foreach ($b in $requiredBlocks) {
    $bPath = Join-Path $ProjectRoot "blocks\$b.liquid"
    Assert-Test "Block file exists: blocks/$b.liquid" (Test-Path $bPath) "Missing block file: $bPath"
}

# Verify footer.liquid schema allowed blocks
$footerLiquidContent = [System.IO.File]::ReadAllText($footerLiquid, [System.Text.Encoding]::UTF8)
Assert-Test "sections/footer.liquid enabled_on groups contains 'footer'" ($footerLiquidContent -match '"enabled_on"\s*:\s*\{\s*"groups"\s*:\s*\[[^\]]*"footer"[^\]]*\]')
Assert-Test "sections/footer.liquid allows 'group' block" ($footerLiquidContent -match '"type"\s*:\s*"group"')
Assert-Test "sections/footer.liquid allows 'menu' block" ($footerLiquidContent -match '"type"\s*:\s*"menu"')
Assert-Test "sections/footer.liquid allows 'payment-icons' block" ($footerLiquidContent -match '"type"\s*:\s*"payment-icons"')

# Verify footer-utilities.liquid schema allowed blocks
$utilLiquidContent = [System.IO.File]::ReadAllText($utilLiquid, [System.Text.Encoding]::UTF8)
Assert-Test "sections/footer-utilities.liquid enabled_on groups contains 'footer'" ($utilLiquidContent -match '"enabled_on"\s*:\s*\{\s*"groups"\s*:\s*\[[^\]]*"footer"[^\]]*\]')
Assert-Test "sections/footer-utilities.liquid allows 'footer-copyright' block" ($utilLiquidContent -match '"type"\s*:\s*"footer-copyright"')
Assert-Test "sections/footer-utilities.liquid allows 'footer-policy-list' block" ($utilLiquidContent -match '"type"\s*:\s*"footer-policy-list"')
Assert-Test "sections/footer-utilities.liquid allows 'social-links' block" ($utilLiquidContent -match '"type"\s*:\s*"social-links"')
Assert-Test "sections/footer-utilities.liquid enforces max_blocks 3" ($utilLiquidContent -match '"max_blocks"\s*:\s*3')
Assert-Test "sections/footer-group.json utilities block count is <= 3" ($utilBlocks.Count -le 3)

# Verify blocks/group.liquid allows @theme blocks
$groupLiquidContent = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "blocks\group.liquid"), [System.Text.Encoding]::UTF8)
Assert-Test "blocks/group.liquid allows '@theme' nested theme blocks" ($groupLiquidContent -match '"type"\s*:\s*"@theme"')

# ------------------------------------------------------------------------------
# 4. Brand Styling & Design Token Binding Verification (R1 / R4)
# ------------------------------------------------------------------------------
Write-Host "`n--- 4. Brand Styling & Design Token Binding Verification ---" -ForegroundColor Yellow

$footerSettings = $parsedPS.sections.footer.settings
Assert-Test "Footer background_color is Soft Beige ('{{ settings.color_palette.color2 }}')" ($footerSettings.background_color -eq "{{ settings.color_palette.color2 }}") "Got: $($footerSettings.background_color)"

$utilSettings = $parsedPS.sections.utilities.settings
Assert-Test "Utilities background_color is Soft Beige ('{{ settings.color_palette.color2 }}')" ($utilSettings.background_color -eq "{{ settings.color_palette.color2 }}") "Got: $($utilSettings.background_color)"
Assert-Test "Utilities divider_color is White ('{{ settings.color_palette.color3 }}')" ($utilSettings.divider_color -eq "{{ settings.color_palette.color3 }}") "Got: $($utilSettings.divider_color)"
Assert-Test "Utilities divider_thickness is 1px" ($utilSettings.divider_thickness -eq 1) "Got: $($utilSettings.divider_thickness)"

$emailSignup = $parsedPS.sections.footer.blocks.group_newsletter.blocks.email_signup.settings
Assert-Test "Email signup input_style is 'custom'" ($emailSignup.input_style -eq "custom")
Assert-Test "Email signup border_radius is 100 (pill)" ($emailSignup.border_radius -eq 100)
Assert-Test "Email signup input_background_color is Warm Ivory ('{{ settings.color_palette.background }}')" ($emailSignup.input_background_color -eq "{{ settings.color_palette.background }}")
Assert-Test "Email signup input_border_color is White ('{{ settings.color_palette.color3 }}')" ($emailSignup.input_border_color -eq "{{ settings.color_palette.color3 }}")
Assert-Test "Email signup style_class is 'button-custom'" ($emailSignup.style_class -eq "button-custom")
Assert-Test "Email signup custom_button_background is Dusty Rose ('{{ settings.color_palette.color1 }}')" ($emailSignup.custom_button_background -eq "{{ settings.color_palette.color1 }}")
Assert-Test "Email signup custom_button_border is Dusty Rose ('{{ settings.color_palette.color1 }}')" ($emailSignup.custom_button_border -eq "{{ settings.color_palette.color1 }}")
Assert-Test "Email signup custom_button_text is '#FFFFFF'" ($emailSignup.custom_button_text -eq "#FFFFFF")

# ------------------------------------------------------------------------------
# 5. Content & Brand Copy Integrity (R4)
# ------------------------------------------------------------------------------
Write-Host "`n--- 5. Content & Brand Copy Integrity ---" -ForegroundColor Yellow

$headingText = $parsedPS.sections.footer.blocks.group_newsletter.blocks.text_heading.settings.text
Assert-Test "Newsletter heading is '<h3>Join the HERAVYN Movement</h3>'" ($headingText -eq "<h3>Join the HERAVYN Movement</h3>") "Got: $headingText"

$subcopyText = $parsedPS.sections.footer.blocks.group_newsletter.blocks.text_subcopy.settings.text
Assert-Test "Newsletter subcopy contains 'STRONGER YOU' ethos" ($subcopyText -match "STRONGER YOU") "Got: $subcopyText"

$shopMenu = $parsedPS.sections.footer.blocks.menu_shop.settings
Assert-Test "Shop menu has heading 'Shop'" ($shopMenu.heading -eq "Shop")
Assert-Test "Shop menu links to 'main-menu'" ($shopMenu.menu -eq "main-menu")

$careMenu = $parsedPS.sections.footer.blocks.menu_care.settings
Assert-Test "Customer Care menu has heading 'Customer Care'" ($careMenu.heading -eq "Customer Care")
Assert-Test "Customer Care menu links to 'footer'" ($careMenu.menu -eq "footer")

$paymentIcons = $parsedPS.sections.footer.blocks.payment_icons
Assert-Test "Payment icons block is present in footer section" ($paymentIcons.type -eq "payment-icons")

$copyright = $parsedPS.sections.utilities.blocks.copyright.settings
Assert-Test "Copyright show_powered_by is false" ($copyright.show_powered_by -eq $false)

$social = $parsedPS.sections.utilities.blocks.social_icons.settings
Assert-Test "Instagram URL includes profile path (/heravyn)" ($social.instagram_url -match "instagram\.com/heravyn")
Assert-Test "TikTok URL includes profile path (/@heravyn)" ($social.tiktok_url -match "tiktok\.com/@heravyn")
Assert-Test "YouTube URL includes profile path (/@heravyn)" ($social.youtube_url -match "youtube\.com/@heravyn")
Assert-Test "Facebook URL includes profile path (/heravyn)" ($social.facebook_url -match "facebook\.com/heravyn")

# ------------------------------------------------------------------------------
# 6. Responsive Grid & Layout Calculations
# ------------------------------------------------------------------------------
Write-Host "`n--- 6. Responsive Grid & Layout Calculations ---" -ForegroundColor Yellow

# Footer section: 4 blocks -> exactly 4 columns desktop (at_most: 4), 2 cols tablet, 1 col mobile
$footerBlockCount = $footerBlocks.Count
Assert-Test "Footer block count is exactly 4 (triggers 4-col desktop, 2x2 tablet, 1-col mobile)" ($footerBlockCount -eq 4) "Count: $footerBlockCount"

# Utilities section: exactly 3 blocks -> triggers .utilities--blocks-3 (1fr auto 1fr on desktop, flex column mobile)
$utilBlockCount = $utilBlocks.Count
Assert-Test "Utilities block count is exactly 3 (triggers .utilities--blocks-3 3-column layout)" ($utilBlockCount -eq 3) "Count: $utilBlockCount"

# ------------------------------------------------------------------------------
# 7. Git Scope & Platform Integrity
# ------------------------------------------------------------------------------
Write-Host "`n--- 7. Git Scope & Platform Integrity ---" -ForegroundColor Yellow

# Check theme.liquid platform hooks
$themeLiquidPath = Join-Path $ProjectRoot "layout\theme.liquid"
$themeLiquid = [System.IO.File]::ReadAllText($themeLiquidPath, [System.Text.Encoding]::UTF8)
Assert-Test "layout/theme.liquid renders content_for_header" ($themeLiquid -match 'content_for_header')
Assert-Test "layout/theme.liquid renders content_for_layout" ($themeLiquid -match 'content_for_layout')
Assert-Test "layout/theme.liquid renders sections 'footer-group'" ($themeLiquid -match "sections\s+'footer-group'")

# Check git status for M4 scope
$gitStatus = git status --porcelain
$modifiedFiles = $gitStatus -split '\r?\n' | Where-Object { $_ -match '^\s*M\s+' } | ForEach-Object { ($_ -replace '^\s*M\s+', '').Trim() }
$liquidModified = $modifiedFiles | Where-Object { $_ -match '\.liquid$' }
Assert-Test "Zero .liquid files modified in workspace" ($liquidModified.Count -eq 0) "Modified liquid: $($liquidModified -join ', ')"

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 4 Adversarial Verification Results" -ForegroundColor Cyan
Write-Host "Total Checks : $TotalChecks" -ForegroundColor Cyan
Write-Host "Passed Checks: $PassedChecks" -ForegroundColor Green
Write-Host "Failed Checks: $FailedChecks" -ForegroundColor $(if ($FailedChecks -eq 0) { "Green" } else { "Red" })
Write-Host "======================================================================" -ForegroundColor Cyan

if ($FailedChecks -gt 0) {
    Write-Host "`nFailures detected:" -ForegroundColor Red
    foreach ($issue in $Issues) {
        Write-Host "  $issue" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`n[VERDICT: APPROVE] sections/footer-group.json strictly meets all architectural, schema, brand, and responsive requirements." -ForegroundColor Green
    exit 0
}
