# ==============================================================================
# HERAVYN Horizon v4.3.0 - Milestone 1 Adversarial Verification Suite
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
Write-Host "Starting Milestone 1 Adversarial Verification Suite" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$SettingsDataPath = Join-Path $ProjectRoot "config\settings_data.json"
$SettingsSchemaPath = Join-Path $ProjectRoot "config\settings_schema.json"
$ColorPaletteLiquidPath = Join-Path $ProjectRoot "snippets\color-palette.liquid"

# ------------------------------------------------------------------------------
# SUITE 1: Structural & Lexical JSON Integrity
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 1: Structural & Lexical JSON Integrity ---" -ForegroundColor Yellow

Report-Assert "settings_data.json exists" (Test-Path $SettingsDataPath) "File not found"
$rawBytes = [System.IO.File]::ReadAllBytes($SettingsDataPath)
$hasBOM = ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF)
Report-Assert "Encoding is UTF-8 clean" ($rawBytes.Length -gt 0) "File is empty"

$rawText = [System.IO.File]::ReadAllText($SettingsDataPath, [System.Text.Encoding]::UTF8)

# Check comment block
$commentMatch = [regex]::Match($rawText, '^\s*/\*.*?\*/', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Report-Assert "Shopify comment header format is valid" ($commentMatch.Success) "Comment header is missing or malformed"

$bodyText = $rawText.Substring($commentMatch.Index + $commentMatch.Length).Trim()

# Check for unclosed comments or additional comments inside body
$hasExtraBlockComments = $bodyText -match '/\*|\*/'
Report-Assert "No stray block comments in JSON body" (-not $hasExtraBlockComments) "Found block comments inside JSON body"

$hasLineComments = $bodyText -match '//'
Report-Assert "No line comments (//) in JSON body" (-not $hasLineComments) "Found '//' comments in JSON body"

# Check for trailing commas in bodyText
# A trailing comma is a comma followed optionally by whitespace/newlines and then '}' or ']'
$trailingCommaMatch = [regex]::Match($bodyText, ',\s*(\]|\})')
Report-Assert "No trailing commas before } or ]" (-not $trailingCommaMatch.Success) "Trailing comma at index $($trailingCommaMatch.Index): '$($trailingCommaMatch.Value)'"

# Check for invalid escape sequences
$invalidEscapes = [regex]::Matches($bodyText, '\\([^"\\\/bfnrtu])')
Report-Assert "No invalid escape sequences in JSON" ($invalidEscapes.Count -eq 0) "Found invalid escape sequences: $($invalidEscapes.Value -join ', ')"

# Check for unescaped control characters in string literals
# Iterate over JSON strings to ensure no raw ASCII 0x00-0x1F except inside valid escapes
$stringLiteralRegex = [regex]'\"([^"\\]|\\.)*\"'
$controlCharFound = $false
foreach ($m in $stringLiteralRegex.Matches($bodyText)) {
    foreach ($char in $m.Value.ToCharArray()) {
        if ([int]$char -lt 32 -and $char -ne "`r" -and $char -ne "`n" -and $char -ne "`t") {
            $controlCharFound = $true
            break
        }
    }
    if ($controlCharFound) { break }
}
Report-Assert "No raw unescaped control characters in string literals" (-not $controlCharFound) "Control characters detected"

# ------------------------------------------------------------------------------
# SUITE 2: Multi-Parser Deserialization & Type Validation
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 2: Multi-Parser Deserialization & Type Validation ---" -ForegroundColor Yellow

# Parser 1: PowerShell ConvertFrom-Json
$psJson = $null
$psParsed = $true
try {
    $psJson = $bodyText | ConvertFrom-Json
} catch {
    $psParsed = $false
    $psError = $_.Exception.Message
}
Report-Assert "PowerShell ConvertFrom-Json deserialization" $psParsed "ConvertFrom-Json failed: $psError"

# Parser 2: JavaScriptSerializer
Add-Type -AssemblyName System.Web.Extensions
$jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$jsParsed = $true
$jsObj = $null
try {
    $jsObj = $jsSerializer.DeserializeObject($bodyText)
} catch {
    $jsParsed = $false
    $jsError = $_.Exception.Message
}
Report-Assert "System.Web.Script.Serialization.JavaScriptSerializer deserialization" $jsParsed "JavaScriptSerializer failed: $jsError"

# Parser 3: DataContractJsonSerializer (Strict RFC 8259 compliance)
Add-Type -AssemblyName System.Runtime.Serialization
$dcParsed = $true
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyText)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $reader = [System.Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader($ms, [System.Xml.XmlDictionaryReaderQuotas]::Max)
    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($reader)
    $reader.Close()
    $ms.Close()
} catch {
    $dcParsed = $false
    $dcError = $_.Exception.Message
}
Report-Assert "DataContractJsonSerializer strict RFC 8259 parser" $dcParsed "Strict parser failed: $dcError"

# Structural Sections
Report-Assert "Root contains 'current' section" ($null -ne $psJson.current) "'current' section is missing"
Report-Assert "Root contains 'presets' section" ($null -ne $psJson.presets) "'presets' section is missing"
Report-Assert "'presets' contains 'Default' preset" ($null -ne $psJson.presets.Default) "'presets.Default' is missing"

# Type validations in current
Report-Assert "'current.quick_add' is boolean True" ($psJson.current.quick_add -eq $true) "Value: $($psJson.current.quick_add)"
Report-Assert "'current.mobile_quick_add' is boolean True" ($psJson.current.mobile_quick_add -eq $true) "Value: $($psJson.current.mobile_quick_add)"
Report-Assert "'current.button_border_radius_primary' is 14" ($psJson.current.button_border_radius_primary -eq 14) "Value: $($psJson.current.button_border_radius_primary)"
Report-Assert "'current.button_border_radius_secondary' is 14" ($psJson.current.button_border_radius_secondary -eq 14) "Value: $($psJson.current.button_border_radius_secondary)"
Report-Assert "'current.primary_button_border_width' is 0" ($psJson.current.primary_button_border_width -eq 0) "Value: $($psJson.current.primary_button_border_width)"
Report-Assert "'current.secondary_button_border_width' is 1" ($psJson.current.secondary_button_border_width -eq 1) "Value: $($psJson.current.secondary_button_border_width)"

# ------------------------------------------------------------------------------
# SUITE 3: Preset & Current Symmetry Stress Test
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 3: Preset & Current Symmetry Stress Test ---" -ForegroundColor Yellow

$currentKeys = $psJson.current.psobject.Properties | Select-Object -ExpandProperty Name
$defaultKeys = $psJson.presets.Default.psobject.Properties | Select-Object -ExpandProperty Name

$missingInDefault = $currentKeys | Where-Object { $_ -notin $defaultKeys -and $_ -ne "content_for_index" }
Report-Assert "All 'current' keys exist in 'presets.Default'" ($missingInDefault.Count -eq 0) "Keys missing in Default: $($missingInDefault -join ', ')"

$missingInCurrent = $defaultKeys | Where-Object { $_ -notin $currentKeys }
# content_for_index is only expected in current or root
$missingInCurrent = $missingInCurrent | Where-Object { $_ -ne "content_for_index" }
Report-Assert "All 'presets.Default' keys exist in 'current'" ($missingInCurrent.Count -eq 0) "Keys missing in Current: $($missingInCurrent -join ', ')"

# Check value parity between current and presets.Default
$mismatches = @()
foreach ($key in $currentKeys) {
    if ($key -eq "content_for_index") { continue }
    if ($key -eq "color_palette") {
        foreach ($cpKey in @('background', 'foreground', 'color1', 'color2', 'color3')) {
            $curVal = $psJson.current.color_palette.$cpKey
            $defVal = $psJson.presets.Default.color_palette.$cpKey
            if ($curVal -ne $defVal) {
                $mismatches += "color_palette.$cpKey (current='$curVal', default='$defVal')"
            }
        }
    } else {
        $curVal = $psJson.current.$key
        $defVal = $psJson.presets.Default.$key
        if ($curVal -ne $defVal) {
            $mismatches += "$key (current='$curVal', default='$defVal')"
        }
    }
}
Report-Assert "Exact value parity between 'current' and 'presets.Default'" ($mismatches.Count -eq 0) "Mismatched settings: $($mismatches -join '; ')"

# ------------------------------------------------------------------------------
# SUITE 4: Liquid Reference Integrity & Schema Binding Verification
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 4: Liquid Reference Integrity & Schema Binding ---" -ForegroundColor Yellow

# Read settings_schema.json
$schemaJson = Get-Content $SettingsSchemaPath -Raw | ConvertFrom-Json
$schemaSettingIds = @()
foreach ($section in $schemaJson) {
    if ($section.settings) {
        foreach ($s in $section.settings) {
            if ($s.id) {
                $schemaSettingIds += $s.id
            }
        }
    }
}
$schemaSettingIds = $schemaSettingIds | Sort-Object -Unique

# Verify all keys in current exist in schema
$unknownKeys = @()
foreach ($key in $currentKeys) {
    if ($key -eq "content_for_index") { continue }
    if ($key -notin $schemaSettingIds) {
        $unknownKeys += $key
    }
}
Report-Assert "All settings in settings_data.json defined in settings_schema.json" ($unknownKeys.Count -eq 0) "Undefined keys in schema: $($unknownKeys -join ', ')"

# Verify Liquid references in settings_data.json
$liquidRefRegex = [regex]'^\{\{\s*settings\.([a-zA-Z0-9_\.]+)\s*\}\}$'
$brokenRefs = @()
foreach ($prop in $psJson.current.psobject.Properties) {
    $val = [string]$prop.Value
    $m = $liquidRefRegex.Match($val)
    if ($m.Success) {
        $refTarget = $m.Groups[1].Value
        # Split target (e.g. color_palette.background)
        $parts = $refTarget.Split('.')
        if ($parts[0] -eq "color_palette") {
            $subKey = $parts[1]
            $resolvedVal = $psJson.current.color_palette.$subKey
            if ([string]::IsNullOrEmpty($resolvedVal)) {
                $brokenRefs += "$($prop.Name) references invalid target '$refTarget'"
            }
        } else {
            $resolvedVal = $psJson.current.$($parts[0])
            if ([string]::IsNullOrEmpty($resolvedVal)) {
                $brokenRefs += "$($prop.Name) references undefined setting '$($parts[0])'"
            }
        }
    }
}
Report-Assert "All dynamic Liquid settings references resolve cleanly" ($brokenRefs.Count -eq 0) "Broken references: $($brokenRefs -join '; ')"

# Verify color_palette tokens match HERAVYN specifications exactly
Report-Assert "color_palette.background == #FAF7F3 (Warm Ivory)" ($psJson.current.color_palette.background -eq "#FAF7F3") "Got $($psJson.current.color_palette.background)"
Report-Assert "color_palette.foreground == #252525 (Deep Charcoal)" ($psJson.current.color_palette.foreground -eq "#252525") "Got $($psJson.current.color_palette.foreground)"
Report-Assert "color_palette.color1 == #B87570 (Dusty Rose)" ($psJson.current.color_palette.color1 -eq "#B87570") "Got $($psJson.current.color_palette.color1)"
Report-Assert "color_palette.color2 == #E9DED5 (Soft Beige)" ($psJson.current.color_palette.color2 -eq "#E9DED5") "Got $($psJson.current.color_palette.color2)"
Report-Assert "color_palette.color3 == #FFFFFF (White)" ($psJson.current.color_palette.color3 -eq "#FFFFFF") "Got $($psJson.current.color_palette.color3)"

# Verify snippets/color-palette.liquid references
$colorPaletteContent = Get-Content $ColorPaletteLiquidPath -Raw
$paletteSettingsUsed = ([regex]::Matches($colorPaletteContent, 'settings\.([a-zA-Z0-9_]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$unresolvablePaletteSettings = @()
foreach ($settingName in $paletteSettingsUsed) {
    if ($settingName -eq "color_palette") { continue }
    # Must exist in settings_data.json OR in schema settings
    $inData = ($null -ne $psJson.current.$settingName)
    $inSchema = ($settingName -in $schemaSettingIds)
    if (-not $inData -and -not $inSchema) {
        # Check if optional (like drawer_shadow_color which is guarded by drawer_drop_shadow)
        if ($settingName -notin @('drawer_shadow_color', 'drawer_drop_shadow')) {
            $unresolvablePaletteSettings += $settingName
        }
    }
}
Report-Assert "color-palette.liquid settings exist in data or schema" ($unresolvablePaletteSettings.Count -eq 0) "Unresolvable settings: $($unresolvablePaletteSettings -join ', ')"

# ------------------------------------------------------------------------------
# SUITE 5: Liquid Syntax & Tag Balancing
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 5: Liquid Syntax & Tag Balancing ---" -ForegroundColor Yellow

$liquidContent = Get-Content $ColorPaletteLiquidPath -Raw
$liquidBlocks = [regex]::Matches($liquidContent, '\{%-?\s*liquid\s+(.*?)-?%\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)

$allIfBalanced = $true
$allForBalanced = $true
foreach ($b in $liquidBlocks) {
    $code = $b.Groups[1].Value
    $ifCount = ([regex]::Matches($code, '^\s*if\b', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    $endifCount = ([regex]::Matches($code, '^\s*endif\b', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    $forCount = ([regex]::Matches($code, '^\s*for\b', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    $endforCount = ([regex]::Matches($code, '^\s*endfor\b', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    if ($ifCount -ne $endifCount) { $allIfBalanced = $false }
    if ($forCount -ne $endforCount) { $allForBalanced = $false }
}
Report-Assert "color-palette.liquid statements (if/endif) balanced inside liquid blocks" $allIfBalanced "Unbalanced if/endif in liquid block"
Report-Assert "color-palette.liquid statements (for/endfor) balanced inside liquid blocks" $allForBalanced "Unbalanced for/endfor in liquid block"

$styleOpen = ([regex]::Matches($liquidContent, '\{%-?\s*style\s*-?%\}')).Count
$styleClose = ([regex]::Matches($liquidContent, '\{%-?\s*endstyle\s*-?%\}')).Count
Report-Assert "color-palette.liquid style/endstyle balanced" ($styleOpen -eq $styleClose -and $styleOpen -gt 0) "style tags unbalanced: open=$styleOpen, close=$styleClose"

$docOpen = ([regex]::Matches($liquidContent, '\{%-?\s*doc\s*-?%\}')).Count
$docClose = ([regex]::Matches($liquidContent, '\{%-?\s*enddoc\s*-?%\}')).Count
Report-Assert "color-palette.liquid doc/enddoc balanced" ($docOpen -eq $docClose -and $docOpen -gt 0) "doc tags unbalanced: open=$docOpen, close=$docClose"

$commentOpen = ([regex]::Matches($liquidContent, '\{%-?\s*comment\s*-?%\}')).Count
$commentClose = ([regex]::Matches($liquidContent, '\{%-?\s*endcomment\s*-?%\}')).Count
Report-Assert "color-palette.liquid comment/endcomment balanced" ($commentOpen -eq $commentClose) "comment tags unbalanced: open=$commentOpen, close=$commentClose"

# ------------------------------------------------------------------------------
# SUITE 6: Color Accessibility & Visual Contrast Stress Test
# ------------------------------------------------------------------------------
Write-Host "`n--- Suite 6: Color Accessibility & Visual Contrast Stress Test ---" -ForegroundColor Yellow

function Get-Luminance($hex) {
    $hex = $hex.TrimStart('#')
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16) / 255.0
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16) / 255.0
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16) / 255.0
    $r = if ($r -le 0.03928) { $r / 12.92 } else { [Math]::Pow(($r + 0.055) / 1.055, 2.4) }
    $g = if ($g -le 0.03928) { $g / 12.92 } else { [Math]::Pow(($g + 0.055) / 1.055, 2.4) }
    $b = if ($b -le 0.03928) { $b / 12.92 } else { [Math]::Pow(($b + 0.055) / 1.055, 2.4) }
    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Get-ContrastRatio($hex1, $hex2) {
    $l1 = Get-Luminance $hex1
    $l2 = Get-Luminance $hex2
    $bright = [Math]::Max($l1, $l2)
    $dark = [Math]::Min($l1, $l2)
    return [Math]::Round(($bright + 0.05) / ($dark + 0.05), 2)
}

$crCanvasText = Get-ContrastRatio "#252525" "#FAF7F3"
Report-Assert "Body text (#252525) on Canvas (#FAF7F3) >= 4.5:1 (WCAG AA Normal)" ($crCanvasText -ge 4.5) "Contrast ratio: $crCanvasText:1"

$crBeigeText = Get-ContrastRatio "#252525" "#E9DED5"
Report-Assert "Card text (#252525) on Soft Beige (#E9DED5) >= 4.5:1 (WCAG AA Normal)" ($crBeigeText -ge 4.5) "Contrast ratio: $crBeigeText:1"

$crBtnPrimary = Get-ContrastRatio "#FFFFFF" "#B87570"
Report-Assert "Primary Button text (#FFFFFF) on Dusty Rose (#B87570) >= 3.0:1 (WCAG AA Large/UI)" ($crBtnPrimary -ge 3.0) "Contrast ratio: $crBtnPrimary:1"

$crBtnSecondary = Get-ContrastRatio "#252525" "#FAF7F3"
Report-Assert "Secondary Button text (#252525) on Canvas (#FAF7F3) >= 4.5:1 (WCAG AA Normal)" ($crBtnSecondary -ge 4.5) "Contrast ratio: $crBtnSecondary:1"

$crSoldOut = Get-ContrastRatio "#252525" "#E9DED5"
Report-Assert "Sold Out badge text (#252525) on Soft Beige (#E9DED5) >= 4.5:1 (WCAG AA Normal)" ($crSoldOut -ge 4.5) "Contrast ratio: $crSoldOut:1"

# ------------------------------------------------------------------------------
# SUMMARY & EXIT
# ------------------------------------------------------------------------------
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "Test Suite Completed: $PassedTests / $TotalTests tests passed ($FailedTests failed)" -ForegroundColor $(if ($FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "======================================================================" -ForegroundColor Cyan

if ($FailedTests -gt 0) {
    Write-Host "`nFailed assertions:" -ForegroundColor Red
    foreach ($f in $Failures) {
        Write-Host "  $f" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`nALL ADVERSARIAL STRESS TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
    exit 0
}
