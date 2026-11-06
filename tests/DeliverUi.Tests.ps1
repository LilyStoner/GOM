$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'App.ps1') -NoShow
$script:language='English'
if ($ProjectProfileCombo.Parent -isnot [Windows.Controls.StackPanel]) { throw 'Profile selector must not be enclosed in a second bordered control' }
if ($ProjectProfileCombo.Items.Count -ne 2) { throw 'Profile choices must remain available' }
[void]$PasteInput.ApplyTemplate()
if (-not $PasteInput.Template.FindName('PART_ContentHost',$PasteInput)) { throw 'Paste text box must keep its editable content host' }
$PasteInput.Text="one.sql`r`ntwo.SQL"
if (-not $PasteInput.AcceptsReturn -or $PasteInput.Text -ne "one.sql`r`ntwo.SQL") { throw 'Multiline paste input is not supported' }
if ($filterButtons.Count -ne 5) { throw 'All five review filters must be available' }
$FilterSqlButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if ($FilterBox.SelectedIndex -ne 3) { throw 'SQL filter button did not update the review filter' }
$FilterAllButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
$SearchBox.Text='example'
if ($ClearSearchButton.Visibility -ne 'Visible') { throw 'Search clear action should appear when text is present' }
$ClearSearchButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
if ($SearchBox.Text -ne '' -or $ClearSearchButton.Visibility -ne 'Collapsed') { throw 'Search clear action did not clear text' }
if (-not $BranchDestination.IsChecked -or $DuplicateMode.SelectedIndex -ne 1) { throw 'Wrong delivery defaults' }
if ($StartDeliveryButton.IsEnabled) { throw 'Start must be disabled without a destination' }
if (Invoke-DeliveryShortcut 'D2') { throw 'Review shortcut must be guarded before files are added' }
$source=Get-Item (Join-Path $script:appRoot 'UI.xaml')
$item=New-DeliveryItem -File $source -Source $script:appRoot -Profile 'BSC'
$item | Add-Member NoteProperty FileName $source.Name
$item | Add-Member NoteProperty FileType 'XAML'
$item | Add-Member NoteProperty SourceFolder $script:appRoot
[void]($item | Add-Member NoteProperty GitDiff $null)
[void]$script:items.Add($item)
Update-Ui
$FileGrid.SelectedItem=$item
if($ViewChangesButton.IsEnabled){throw 'Manual files must not offer branch comparison'}
$item.GitDiff=[pscustomobject]@{BaseCommit='test'}
$FileGrid.SelectedItem=$null;$FileGrid.SelectedItem=$item
if(-not $ViewChangesButton.IsEnabled){throw 'Git comparison files should enable View Git diff'}
$item.DeliveryResult='Failed';$FilterBox.SelectedIndex=4
if($script:viewItems.Count -ne 1){throw 'Errors filter must include failed delivery results'}
$item.DeliveryResult='';$FilterBox.SelectedIndex=0
if (-not (Invoke-DeliveryShortcut 'D2') -or $script:currentStep -ne 2) { throw 'Review shortcut did not open Review' }
if (-not (Invoke-DeliveryShortcut 'D3') -or $script:currentStep -ne 3) { throw 'Deliver shortcut did not open Deliver' }
$BackToReviewButton.IsEnabled=$false
if (Invoke-DeliveryShortcut 'D1') { throw 'Step shortcuts must be blocked during delivery' }
$BackToReviewButton.IsEnabled=$true
$ExistingDestination.IsChecked=$true
$DestinationPath.Text=$env:TEMP
Update-DestinationState
if (-not $StartDeliveryButton.IsEnabled) { throw 'Existing destination should enable Start' }
if (-not $ConflictInfo.Text) { throw 'Destination collision summary must be visible' }
$DestinationPath.Text='relative-path'
Update-DestinationState
if ($StartDeliveryButton.IsEnabled) { throw 'Relative destination must disable Start' }
$BranchDestination.IsChecked=$true
$DestinationPath.Text=$env:TEMP
$CompareBranch.Text=''
Update-DestinationState
if ($StartDeliveryButton.IsEnabled) { throw 'Branch mode requires a branch' }
if ($OpenManifestButton.Visibility -ne 'Collapsed') { throw 'Manifest action should be hidden' }
$CreateRunScript.IsChecked=$false
if ($SqlPathWarning.Visibility -ne 'Collapsed') { throw 'SQL path warning should be hidden when script generation is off' }
$CreateRunScript.IsChecked=$true
if ($SqlPathWarning.Visibility -ne 'Visible') { throw 'SQL path warning should appear when script generation is on' }
Set-Theme 'Dark'
if ($window.Resources['PrimaryForeground'].Color.ToString() -ne '#FFFFFFFF') { throw 'Primary text must be white in dark mode' }
if ($window.Resources['PrimaryBackground'].Color.ToString() -ne '#FF2F6FE4') { throw 'Dark primary background is incorrect' }
$window.Width=960;$window.Height=640
$window.Measure([Windows.Size]::new(960,640))
$window.Arrange([Windows.Rect]::new(0,0,960,640))
Set-Theme 'Light'
$oldThemePath=$script:themeSettingsPath;$oldPreference=$script:themePreference
$script:themeSettingsPath=Join-Path $env:TEMP ('delivery-theme-test-'+[guid]::NewGuid().ToString('N')+'.json')
try {
    Set-ThemePreference 'Dark'
    if ((Get-SavedTheme) -ne 'Dark' -or $script:theme -ne 'Dark') { throw 'Dark theme preference failed' }
    Set-ThemePreference 'System'
    if ((Get-SavedTheme) -ne 'System' -or $script:theme -ne (Get-SystemAppTheme)) { throw 'System theme preference failed' }
} finally {
    if(Test-Path -LiteralPath $script:themeSettingsPath){Remove-Item -LiteralPath $script:themeSettingsPath -Force}
    $script:themeSettingsPath=$oldThemePath;$script:themePreference=$oldPreference
}
$script:items.Clear()
for($i=0;$i -lt 663;$i++){
    $row=New-DeliveryItem -File $source -Source $script:appRoot -Profile 'BSC'
    $row|Add-Member NoteProperty FileName $source.Name
    $row|Add-Member NoteProperty FileType 'XAML'
    $row|Add-Member NoteProperty SourceFolder $script:appRoot
    $row|Add-Member NoteProperty PackageDirectory ''
    $row|Add-Member NoteProperty PackageName $source.Name
    [void]$script:items.Add($row)
}
$watch=[Diagnostics.Stopwatch]::StartNew();Update-Ui;$watch.Stop()
if($script:viewItems.Count -ne 663){throw 'Large review list did not contain all 663 items'}
if($watch.Elapsed.TotalSeconds -gt 15){throw "Refreshing 663 items took too long: $($watch.Elapsed.TotalSeconds) seconds"}
$refreshMs=$watch.ElapsedMilliseconds
$script:items[0].Included=$false;$watch.Restart();Update-Ui $false;$watch.Stop();$toggleMs=$watch.ElapsedMilliseconds
if($ReviewSummary.Text -notmatch '662 of 663 included'){throw 'Review summary did not update when a file was excluded'}
Write-Host "Deliver UI state tests passed. 663-file refresh: $refreshMs ms; selection summary: $toggleMs ms."
