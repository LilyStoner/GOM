$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'App.ps1') -NoShow
$dir=Join-Path $env:TEMP ('delivery-language-test-'+[guid]::NewGuid().ToString('N'))
try {
    $script:languageSettingsPath=Join-Path $dir 'language.json'
    if($LanguageCombo.Items.Count -ne 3){throw 'English, Arabic and Vietnamese must be available'}
    $LanguageCombo.SelectedIndex=2
    if($script:language -ne 'Vietnamese'){throw 'Vietnamese was not selected'}
    $window.Content.Measure([Windows.Size]::new(960,640));$window.Content.Arrange([Windows.Rect]::new(0,0,960,640));$window.Content.UpdateLayout()
    if($window.FindName('FlagVietnamese').Visibility -ne 'Visible' -or $window.FindName('FlagEnglish').Visibility -ne 'Collapsed'){throw 'The selected language flag is incorrect'}
    $LanguageCombo.IsDropDownOpen=$true;$window.Content.UpdateLayout()
    $option=$LanguageCombo.Items[2];[void]$option.ApplyTemplate()
    $optionFlag=$option.Template.FindName('OptionFlagVietnamese',$option)
    if(-not $optionFlag -or $optionFlag.Visibility -ne 'Visible'){throw 'The dropdown language option is missing its flag'}
    $LanguageCombo.IsDropDownOpen=$false
    if($LoadBranchesButton.Content -ne 'Tải nhánh'){throw "Vietnamese UI was not applied: $($LoadBranchesButton.Content)"}
    if((Get-LocalizedText 'Loaded 5 branches. Ready to compare.') -ne 'Đã tải 5 nhánh. Sẵn sàng so sánh.'){throw 'Vietnamese dynamic text is incorrect'}
    $deliveryText='Deliver 2 file '+[char]0x00B7+' 15 KB'
    if((Get-LocalizedText $deliveryText) -ne ('Bàn giao 2 file '+[char]0x00B7+' 15 KB')){throw 'Dynamic delivery translation lost content'}
    if((Get-Content $script:languageSettingsPath -Raw | ConvertFrom-Json).Language -ne 'Vietnamese'){throw 'Language preference was not saved'}
    if($window.Language.IetfLanguageTag -ne 'vi-VN' -or $window.FlowDirection -ne 'LeftToRight'){throw 'Vietnamese language or flow direction is incorrect'}
    $LanguageCombo.SelectedIndex=1
    if($script:language -ne 'Arabic' -or $window.FlowDirection -ne 'RightToLeft'){throw 'Arabic selection regressed'}
    $LanguageCombo.SelectedIndex=2
    if($LoadBranchesButton.Content -ne 'Tải nhánh'){throw 'Arabic to Vietnamese switching failed'}
    $LanguageCombo.SelectedIndex=0
    if($LoadBranchesButton.Content -ne 'Load branches'){throw 'Switching back to English failed'}
    Set-Theme 'Light';$light=$DarkModeButton.Content
    Set-Theme 'Dark';$dark=$DarkModeButton.Content
    if($light -eq $dark -or $DarkModeButton.FontFamily.Source -ne 'Segoe MDL2 Assets'){throw 'Theme icon must change visibly with the theme'}
    Write-Host 'Vietnamese language, flags and theme icon tests passed.'
} finally {
    if(Test-Path -LiteralPath $dir){Remove-Item -LiteralPath $dir -Recurse -Force}
}
