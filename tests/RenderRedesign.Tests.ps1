param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'App.ps1') -NoShow
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

# Render only synthetic application state; no Git checkout, DB or user files are changed.
[void](Add-Items -Files @((Get-Item (Join-Path $script:appRoot 'UI.xaml')),(Get-Item (Join-Path $script:appRoot 'Core.SqlPlus.ps1'))) -SourceRoot $script:appRoot)
$script:items[1].Relative='2.HOST\3.Procedure\Example.sql'
$script:items[1].PackageDirectory='2.HOST\3.Procedure\'
$script:items[1].PackageName='Example.sql'
$script:CompareBranch.Text='origin/feature/example'
$script:ExistingDestination.IsChecked=$true
$script:DestinationPath.Text=[IO.Path]::GetTempPath()
Update-Ui
$window.Width=960;$window.Height=640

function Save-Preview([string]$Name) {
    $rootVisual=$window.Content
    $rootVisual.Background=$window.Background
    $rootVisual.Measure([Windows.Size]::new(960,640))
    $rootVisual.Arrange([Windows.Rect]::new(0,0,960,640))
    $rootVisual.UpdateLayout()
    [void]$window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ApplicationIdle)
    $rootVisual.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 960,640,96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($rootVisual)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $OutputDirectory $Name))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}

Set-Theme 'Light';Set-Step 1;Save-Preview 'collect-light.png'
Set-Step 3;Save-Preview 'deliver-light.png'
Set-Theme 'Dark';Set-Step 2;$FileGrid.SelectedItem=$script:items[0];Save-Preview 'review-dark.png'
function Find-RowCheckbox($visual) {
    if($visual -is [Windows.Controls.CheckBox]){return $visual}
    for($i=0;$i -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($visual);$i++){
        $found=Find-RowCheckbox ([Windows.Media.VisualTreeHelper]::GetChild($visual,$i))
        if($found){return $found}
    }
    return $null
}
foreach($row in $script:items){
    $container=$FileGrid.ItemContainerGenerator.ContainerFromItem($row)
    if(-not $container){throw 'A review row was not generated during rendering.'}
    $check=Find-RowCheckbox $container
    if(-not $check -or $check.Visibility -ne 'Visible' -or -not $check.IsChecked -or $check.ActualWidth -lt 16){throw 'A checked review-row checkbox is not rendered correctly.'}
}
Set-Step 3;Save-Preview 'deliver-dark.png'
$script:language='Arabic';Set-WindowLanguage $window;Update-Ui;Set-Step 2;Save-Preview 'review-arabic.png'
Set-Step 3;Save-Preview 'deliver-arabic.png'
$script:isUpdatingLanguage=$true;$LanguageCombo.SelectedIndex=2;$script:isUpdatingLanguage=$false
$script:language='Vietnamese';Set-WindowLanguage $window;Update-Ui;Set-Theme 'Light';Set-Step 1;Save-Preview 'collect-vietnamese.png'
Set-Theme 'Dark';Set-Step 3;Save-Preview 'deliver-vietnamese-dark.png'
function Save-DpiPreview([string]$Name,[int]$Width,[int]$Height,[int]$Dpi) {
    $root=$window.Content
    $root.Background=$window.Background
    $root.Measure([Windows.Size]::new($Width,$Height));$root.Arrange([Windows.Rect]::new(0,0,$Width,$Height));$root.UpdateLayout()
    [void]$window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ApplicationIdle);$root.UpdateLayout()
    $controls=@($LanguageCombo,$DarkModeButton,$Step1Button,$Step2Button,$Step3Button)
    if($script:currentStep -eq 1){$controls+=@($ChooseRepoButton,$LoadBranchesButton,$AddGitChangesButton)}
    if($script:currentStep -eq 2){$controls+=@($SortSqlFlexButton,$ContinueButton,$RemoveSelectedButton)}
    if($script:currentStep -eq 3){$controls+=@($BackToReviewButton,$StartDeliveryButton)}
    foreach($control in $controls){
        $position=$control.TranslatePoint([Windows.Point]::new(0,0),$root)
        if($position.X -lt -0.5 -or $position.Y -lt -0.5 -or $position.X+$control.ActualWidth -gt $Width+0.5 -or $position.Y+$control.ActualHeight -gt $Height+0.5){throw "${Name}: control $($control.Name) is outside the available area"}
    }
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]($Width*$Dpi/96)),([int]($Height*$Dpi/96)),$Dpi,$Dpi,([Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($root)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $OutputDirectory $Name));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
Set-Theme 'Light';Set-Step 1;Save-DpiPreview 'collect-vi-150.png' 910 512 144
Set-Theme 'Dark';Set-Step 2;Save-DpiPreview 'review-vi-dark-150.png' 910 512 144
Set-Step 3;Save-DpiPreview 'deliver-vi-dark-150.png' 910 512 144
Set-Theme 'Light';Set-Step 1;Save-DpiPreview 'collect-vi-200.png' 960 500 192
Set-Theme 'Dark';Set-Step 2;Save-DpiPreview 'review-vi-dark-200.png' 960 500 192
Set-Step 3;Save-DpiPreview 'deliver-vi-dark-200.png' 960 500 192
Set-Theme 'Light';Set-Step 1;Save-DpiPreview 'collect-vi-small-150.png' 853 480 144
Set-Theme 'Dark';Set-Step 2;Save-DpiPreview 'review-vi-small-150.png' 853 480 144
Write-Host 'Rendered redesign previews.'
