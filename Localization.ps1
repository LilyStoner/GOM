$script:localizationFile = Join-Path $script:appRoot 'Localization.json'
if (-not (Test-Path -LiteralPath $script:localizationFile -PathType Leaf)) {
    throw "Localization data was not found at '$script:localizationFile'."
}

try {
    $script:localizationData = Get-Content -LiteralPath $script:localizationFile -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw "Could not read localization data at '$script:localizationFile': $($_.Exception.Message)"
}

$script:englishToArabic = @{}
$script:arabicToEnglish = @{}
$script:englishToVietnamese = @{}
$script:vietnameseToEnglish = @{}
foreach ($entry in $script:localizationData.vi.PSObject.Properties) {
    $script:englishToVietnamese[$entry.Name] = [string]$entry.Value
    $script:vietnameseToEnglish[[string]$entry.Value] = $entry.Name
}
foreach ($entry in $script:localizationData.ar.PSObject.Properties) {
    $script:englishToArabic[$entry.Name] = [string]$entry.Value
    $script:arabicToEnglish[[string]$entry.Value] = $entry.Name
}

function Get-SavedLanguage {
    if (-not (Test-Path -LiteralPath $script:languageSettingsPath -PathType Leaf)) { return 'English' }
    try {
        $settings = Get-Content -LiteralPath $script:languageSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Could not read language settings at '$script:languageSettingsPath': $($_.Exception.Message)"
    }
    if ($settings.Language -notin @('English', 'Arabic', 'Vietnamese')) {
        throw "Language settings at '$script:languageSettingsPath' must contain Language set to 'English', 'Arabic' or 'Vietnamese'."
    }
    return [string]$settings.Language
}

$script:localizedPatternCache=@{}
function Convert-LocalizedValue([string]$Text,[hashtable]$Map) {
    if ($Map.ContainsKey($Text)) { return [string]$Map[$Text] }
    $key=[Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($Map)
    if(-not $script:localizedPatternCache.ContainsKey($key)){$script:localizedPatternCache[$key]=@($Map.GetEnumerator() | Where-Object {$_.Key -match '\{\d+\}'} | Sort-Object { ([regex]::Replace([string]$_.Key, '\{\d+\}', '')).Length } -Descending)}
    foreach ($entry in $script:localizedPatternCache[$key]) {
        if ($entry.Key -notmatch '\{\d+\}') { continue }
        $pattern = [regex]::Replace([regex]::Escape([string]$entry.Key), '\\\{\d+\}', '([\s\S]+?)')
        $match = [regex]::Match($Text, '^' + $pattern + '$')
        if (-not $match.Success) { continue }
        $translated=[string]$entry.Value
        for ($index=1;$index -lt $match.Groups.Count;$index++) { $translated=$translated.Replace('{'+($index-1)+'}',$match.Groups[$index].Value) }
        return $translated
    }
    return $Text
}
function Get-LocalizedText([string]$Text) {
    $english=Convert-LocalizedValue $Text $script:arabicToEnglish
    $english=Convert-LocalizedValue $english $script:vietnameseToEnglish
    if($script:language -eq 'Arabic'){return (Convert-LocalizedValue $english $script:englishToArabic)}
    if($script:language -eq 'Vietnamese'){return (Convert-LocalizedValue $english $script:englishToVietnamese)}
    return $english
}

function Set-WindowLanguage([Windows.Window]$TargetWindow) {
    $isArabic = $script:language -eq 'Arabic'
    $TargetWindow.Title = Get-LocalizedText $TargetWindow.Title
    $TargetWindow.FlowDirection = if ($isArabic) { 'RightToLeft' } else { 'LeftToRight' }
    $TargetWindow.Language = [System.Windows.Markup.XmlLanguage]::GetLanguage($(if ($isArabic) { 'ar-SA' } elseif ($script:language -eq 'Vietnamese') { 'vi-VN' } else { 'en-US' }))

    $pending = New-Object 'System.Collections.Generic.Queue[object]'
    $visited = New-Object 'System.Collections.Generic.HashSet[object]'
    $pending.Enqueue($TargetWindow)
    while ($pending.Count -gt 0) {
        $element = $pending.Dequeue()
        if (-not $visited.Add($element)) { continue }

        if ($element -is [Windows.Controls.TextBlock]) {
            $textProperty = [Windows.Controls.TextBlock]::TextProperty
            $currentText = [string]$element.GetValue($textProperty)
            $localizedText = Get-LocalizedText $currentText
            if ($localizedText -ne $currentText) {
                $element.SetCurrentValue($textProperty, $localizedText)
            }
        }
        if ($element -is [Windows.Controls.ContentControl] -and $element.Content -is [string]) {
            $element.Content = Get-LocalizedText $element.Content
        }
        if ($element -is [Windows.Controls.HeaderedContentControl] -and $element.Header -is [string]) {
            $element.Header = Get-LocalizedText $element.Header
        }
        if ($element -is [Windows.FrameworkElement] -and $element.ToolTip -is [string]) {
            $element.ToolTip = Get-LocalizedText $element.ToolTip
        }
        if ($element -is [Windows.DependencyObject]) {
            foreach ($child in [Windows.LogicalTreeHelper]::GetChildren($element)) {
                if ($child -is [Windows.DependencyObject]) { $pending.Enqueue($child) }
            }
        }
    }

    if ($TargetWindow -eq $script:window) {
        foreach ($column in $script:FileGrid.Columns) {
            if ($column.Header -is [string]) { $column.Header = Get-LocalizedText $column.Header }
        }
        foreach ($name in @('RepoPath', 'BaseBranch', 'CompareBranch', 'SearchBox', 'PasteInput', 'DestinationPath')) {
            $control = $TargetWindow.FindName($name)
            if ($control) { $control.FlowDirection = 'LeftToRight' }
        }
    }
}
