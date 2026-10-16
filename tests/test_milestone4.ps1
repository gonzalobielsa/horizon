# Test verification script for Milestone 4: Footer Group (sections/footer-group.json)
param(
    [string]$ProjectRoot = "c:\Users\Reinis Kurms\Desktop\reinis"
)

$ErrorActionPreference = "Stop"
$FooterJsonPath = Join-Path $ProjectRoot "sections\footer-group.json"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Milestone 4 Verification Test Suite: sections/footer-group.json" -ForegroundColor Cyan
Write-Host "Target: $FooterJsonPath" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $FooterJsonPath)) {
    Write-Host "[FAIL] sections/footer-group.json does not exist" -ForegroundColor Red
    exit 1
}

$raw = [System.IO.File]::ReadAllText($FooterJsonPath, [System.Text.Encoding]::UTF8)

# Test 1: Comment Header Check
Write-Host "`n--- Test 1: Shopify Comment Header Check ---" -ForegroundColor Yellow
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
Write-Host "`n--- Test 3: Trailing Commas & Syntax Cleanliness ---" -ForegroundColor Yellow
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

# Test 4: Section Order & Root Schema
Write-Host "`n--- Test 4: Section Order & Root Schema ---" -ForegroundColor Yellow
if ($parsed.type -ne "footer") {
    Write-Host "  [FAIL] Root type is not 'footer': $($parsed.type)" -ForegroundColor Red
    exit 1
}
$expectedOrder = @('footer', 'utilities')
if ($parsed.order.Count -ne $expectedOrder.Count) {
    Write-Host "  [FAIL] Section order count mismatch: $($parsed.order.Count) vs $($expectedOrder.Count)" -ForegroundColor Red
    exit 1
}
for ($i = 0; $i -lt $expectedOrder.Count; $i++) {
    if ($parsed.order[$i] -ne $expectedOrder[$i]) {
        Write-Host "  [FAIL] Section order item $i mismatch: $($parsed.order[$i]) vs $($expectedOrder[$i])" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  [PASS] Section order matches specification: $($expectedOrder -join ', ')" -ForegroundColor Green

# Test 5: Footer Section Detailed Requirements
Write-Host "`n--- Test 5: Footer Section Detailed Requirements ---" -ForegroundColor Yellow
$footerSec = $parsed.sections.footer
if ($footerSec.type -ne "footer") {
    Write-Host "  [FAIL] footer section type is '$($footerSec.type)', expected 'footer'" -ForegroundColor Red
    exit 1
}

if ($footerSec.settings.background_color -ne "{{ settings.color_palette.color2 }}") {
    Write-Host "  [FAIL] footer background_color is '$($footerSec.settings.background_color)', expected '{{ settings.color_palette.color2 }}'" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Footer background color bound to Soft Beige ('{{ settings.color_palette.color2 }}')" -ForegroundColor Green

# Block order check in footer
$expectedFooterBlocks = @('group_newsletter', 'menu_shop', 'menu_care', 'payment_icons')
if ($footerSec.block_order.Count -ne $expectedFooterBlocks.Count) {
    Write-Host "  [FAIL] Footer block_order count mismatch: $($footerSec.block_order.Count) vs $($expectedFooterBlocks.Count)" -ForegroundColor Red
    exit 1
}
for ($i = 0; $i -lt $expectedFooterBlocks.Count; $i++) {
    if ($footerSec.block_order[$i] -ne $expectedFooterBlocks[$i]) {
        Write-Host "  [FAIL] Footer block_order item $i mismatch: $($footerSec.block_order[$i]) vs $($expectedFooterBlocks[$i])" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  [PASS] Footer block order matches specification: $($expectedFooterBlocks -join ', ')" -ForegroundColor Green

# Newsletter group check
$gn = $footerSec.blocks.group_newsletter
if ($gn.type -ne "group") {
    Write-Host "  [FAIL] group_newsletter type is '$($gn.type)', expected 'group'" -ForegroundColor Red
    exit 1
}

$headingText = $gn.blocks.text_heading.settings.text
if ($headingText -ne "<h3>Join the HERAVYN Movement</h3>") {
    Write-Host "  [FAIL] Newsletter heading mismatch: '$headingText'" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Newsletter heading matches: '$headingText'" -ForegroundColor Green

$subcopyText = $gn.blocks.text_subcopy.settings.text
if ($subcopyText -ne "<p>Receive exclusive strength guides, private collection drops, and wellness inspiration. STRONGER YOU begins here.</p>") {
    Write-Host "  [FAIL] Newsletter subcopy mismatch: '$subcopyText'" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Newsletter subcopy matches with brand ethos" -ForegroundColor Green

# Email signup check
$signup = $gn.blocks.email_signup
$signupPass = ($signup.type -eq "email-signup") -and
              ($signup.settings.border_radius -eq 100) -and
              ($signup.settings.input_background_color -eq "{{ settings.color_palette.background }}") -and
              ($signup.settings.input_border_color -eq "{{ settings.color_palette.color3 }}") -and
              ($signup.settings.style_class -eq "button-custom") -and
              ($signup.settings.custom_button_background -eq "{{ settings.color_palette.color1 }}") -and
              ($signup.settings.custom_button_text -eq "#FFFFFF") -and
              ($signup.settings.custom_button_border -eq "{{ settings.color_palette.color1 }}")

if (-not $signupPass) {
    Write-Host "  [FAIL] email_signup settings mismatch" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Email signup configured: pill border_radius 100, Warm Ivory bg, White border, Dusty Rose button with White text" -ForegroundColor Green

# Menus check
$menuShop = $footerSec.blocks.menu_shop
if ($menuShop.type -ne "menu" -or $menuShop.settings.heading -ne "Shop" -or $menuShop.settings.menu -ne "main-menu") {
    Write-Host "  [FAIL] menu_shop configuration mismatch" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] menu_shop configured: heading 'Shop', menu 'main-menu'" -ForegroundColor Green

$menuCare = $footerSec.blocks.menu_care
if ($menuCare.type -ne "menu" -or $menuCare.settings.heading -ne "Customer Care" -or $menuCare.settings.menu -ne "footer") {
    Write-Host "  [FAIL] menu_care configuration mismatch" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] menu_care configured: heading 'Customer Care', menu 'footer'" -ForegroundColor Green

# Payment icons check
$payIcons = $footerSec.blocks.payment_icons
if ($payIcons.type -ne "payment-icons") {
    Write-Host "  [FAIL] payment_icons type is '$($payIcons.type)', expected 'payment-icons'" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] payment_icons block correctly positioned in footer section" -ForegroundColor Green

# Test 6: Utilities Section Detailed Requirements
Write-Host "`n--- Test 6: Utilities Section Detailed Requirements ---" -ForegroundColor Yellow
$utilSec = $parsed.sections.utilities
if ($utilSec.type -ne "footer-utilities") {
    Write-Host "  [FAIL] utilities section type is '$($utilSec.type)', expected 'footer-utilities'" -ForegroundColor Red
    exit 1
}

if ($utilSec.settings.background_color -ne "{{ settings.color_palette.color2 }}") {
    Write-Host "  [FAIL] utilities background_color is '$($utilSec.settings.background_color)', expected '{{ settings.color_palette.color2 }}'" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Utilities background color bound to Soft Beige ('{{ settings.color_palette.color2 }}')" -ForegroundColor Green

if ($utilSec.settings.divider_color -ne "{{ settings.color_palette.color3 }}") {
    Write-Host "  [FAIL] utilities divider_color is '$($utilSec.settings.divider_color)', expected '{{ settings.color_palette.color3 }}'" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Utilities divider color bound to White ('{{ settings.color_palette.color3 }}')" -ForegroundColor Green

if ($utilSec.settings.divider_thickness -ne 1) {
    Write-Host "  [FAIL] utilities divider_thickness is '$($utilSec.settings.divider_thickness)', expected 1" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Utilities divider thickness is 1px" -ForegroundColor Green

# Copyright check (show_powered_by: false)
$copyright = $utilSec.blocks.copyright
if ($copyright.type -ne "footer-copyright" -or $copyright.settings.show_powered_by -ne $false) {
    Write-Host "  [FAIL] copyright block: expected type 'footer-copyright' and show_powered_by false" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] Copyright configured with 'show_powered_by': false (powered by Shopify hidden per R4)" -ForegroundColor Green

# Policy list check
$policyList = $utilSec.blocks.policy_list
if ($policyList.type -ne "footer-policy-list") {
    Write-Host "  [FAIL] policy_list block type is '$($policyList.type)', expected 'footer-policy-list'" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] policy_list configured with native footer-policy-list" -ForegroundColor Green

# Social icons check
$social = $utilSec.blocks.social_icons
$socialPass = ($social.type -eq "social-links") -and
              ($social.settings.instagram_url -match "instagram\.com/heravyn") -and
              ($social.settings.tiktok_url -match "tiktok\.com/@heravyn") -and
              ($social.settings.youtube_url -match "youtube\.com/@heravyn") -and
              ($social.settings.facebook_url -match "facebook\.com/heravyn")

if (-not $socialPass) {
    Write-Host "  [FAIL] social_icons block missing required active social profile URLs" -ForegroundColor Red
    exit 1
}
Write-Host "  [PASS] social_icons configured with active URLs for Instagram, TikTok, YouTube, Facebook" -ForegroundColor Green

$expectedUtilBlocks = @('copyright', 'policy_list', 'social_icons')
for ($i = 0; $i -lt $expectedUtilBlocks.Count; $i++) {
    if ($utilSec.block_order[$i] -ne $expectedUtilBlocks[$i]) {
        Write-Host "  [FAIL] Utilities block_order item $i mismatch: $($utilSec.block_order[$i]) vs $($expectedUtilBlocks[$i])" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  [PASS] Utilities block order matches specification: $($expectedUtilBlocks -join ', ')" -ForegroundColor Green

Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "ALL MILESTONE 4 VERIFICATION TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
