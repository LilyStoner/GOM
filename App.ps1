[CmdletBinding()]
param([switch]$NoShow)
$ErrorActionPreference='Stop'
if(-not ('GomDpiApi' -as [type])){
    Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public static class GomDpiApi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }'
}
try { [void][GomDpiApi]::SetProcessDPIAware() } catch [System.DllNotFoundException] {} catch [System.EntryPointNotFoundException] {}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $script:appRoot 'Core.Git.ps1');. (Join-Path $script:appRoot 'Core.FileOps.ps1');. (Join-Path $script:appRoot 'Core.SqlPlus.ps1')
. (Join-Path $script:appRoot 'Localization.ps1')
. (Join-Path $script:appRoot 'Core.WindowSettings.ps1')

$script:themeSettingsPath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GOM\theme.json'
$script:languageSettingsPath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GOM\language.json'
$script:windowSettingsPath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GOM\window.json'
function Get-SavedTheme {
    if(-not (Test-Path -LiteralPath $script:themeSettingsPath -PathType Leaf)){return 'System'}
    try {
        $settings=Get-Content -LiteralPath $script:themeSettingsPath -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Could not read theme settings at '$script:themeSettingsPath': $($_.Exception.Message)"
    }
    if($settings.Theme -notin @('System','Light','Dark')){throw "Theme settings at '$script:themeSettingsPath' must contain System, Light or Dark."}
    return [string]$settings.Theme
}
function Get-SystemAppTheme {
    try { $v=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme; if($v -eq 0){return 'Dark'} } catch {}
    return 'Light'
}
$script:themePreference=Get-SavedTheme
$script:theme=if($script:themePreference -eq 'System'){Get-SystemAppTheme}else{$script:themePreference}
$script:language=Get-SavedLanguage
[xml]$xaml=Get-Content -LiteralPath (Join-Path $script:appRoot 'UI.xaml') -Raw -Encoding UTF8
$window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$workArea=[Windows.SystemParameters]::WorkArea
$size=Get-DeliveryWindowSize -Path $script:windowSettingsPath -WorkWidth $workArea.Width -WorkHeight $workArea.Height
$window.MinWidth=$size.MinWidth;$window.MinHeight=$size.MinHeight;$window.Width=$size.Width;$window.Height=$size.Height
$script:normalWindowWidth=$size.Width;$script:normalWindowHeight=$size.Height;$script:windowWasShown=$false
$window.Add_SourceInitialized({$script:windowWasShown=$true})
$window.Add_SizeChanged({if($script:windowWasShown -and $window.WindowState -eq [Windows.WindowState]::Normal -and $window.ActualWidth -gt 0 -and $window.ActualHeight -gt 0){$script:normalWindowWidth=$window.ActualWidth;$script:normalWindowHeight=$window.ActualHeight}})
$window.Add_Closed({if($script:windowWasShown){try {Save-DeliveryWindowSize -Path $script:windowSettingsPath -Width $script:normalWindowWidth -Height $script:normalWindowHeight} catch {}}})

$names=@(
    'InlineStatus','DarkModeButton','LanguageCombo','ProjectProfileCombo','Step1Button','Step2Button','Step3Button',
    'CollectScroll','CollectView','ReviewView','DeliverScroll','DeliverView',
    'CollectProgress','CollectHint','AdvancedCollect',
    'ExcludeRules','PasteInput','AddPathsButton','PasteResult','RepoPath','ChooseRepoButton',
    'BaseBranch','CompareBranch','LoadBranchesButton','AutoCheckoutAndPull','IncludeWorkspace',
    'AddGitChangesButton','GitHint','GitWorkspaceInfo','GitDirtyWarning','ReviewSummary','SearchBox','ClearSearchButton','FilterBox','FilterAllButton','FilterIncludedButton','FilterExcludedButton','FilterSqlButton','FilterErrorsButton','EmptyState','EmptySelectButton',
    'FileGrid','ViewChangesButton','ToggleFilteredButton','SelectAllButton','ClearSelectionButton','SortAscendingButton',
    'SortDescendingButton','SortSqlFlexButton','ReviewActionHint','RemoveSelectedButton','ContinueButton',
    'DeliverTitle','DeliverSummary','DeliverContainer','DeliveryReadyHint','DestinationMode','BranchDestination','ExistingDestination','DestinationPath','ChooseDestinationButton','DestinationInfo',
    'ConflictInfo','DestinationError','BackToReviewButton','DeliveryOptions','DuplicateMode',
    'ProfileDeliveryHint','SqlOptions','CreateRunScript','SqlPathWarning','SqlScriptDescription','SqlConfigError',
    'SqlSettingsLine','ConfigureSqlButton','SqlConfigSummary','VerifyHash','DeliveryProgress',
    'DeliveryStatus','StartDeliveryButton','CancelDeliveryButton','ResultPanel','ResultTitle',
    'ResultSummary','RunAllPanel','RunAllStatus','RunAllProgress','OpenDestinationButton','OpenManifestButton','GenerateMd5Button','ViewRunLogButton','ReviewErrorsButton'
)
foreach($name in $names){Set-Variable -Name $name -Value $window.FindName($name) -Scope Script}

function Set-Theme([string]$Theme,[Windows.Window]$TargetWindow=$window) {
    $light=@{
        '003399'='#003399';'0078D7'='#0078D7';'0645C0'='#0645C0';'0F54B6'='#0F54B6';'1463D6'='#1463D6'
        '16794A'='#16794A';'17263C'='#17263C';'28384D'='#28384D';'536174'='#536174';'5D6B7E'='#4B5768'
        'A96500'='#A96500';'A9C7F5'='#A9C7F5';'B42318'='#B42318';'B8C0CC'='#B8C0CC';'CFE8FA'='#CFE8FA'
        'D7DFE9'='#C5CEDA';'D9DEE7'='#C5CEDA';'E5E9F0'='#E5E9F0';'EAF2FF'='#EAF2FF';'EEF1F5'='#EEF1F5'
        'EEF3FA'='#EEF3FA';'F3B5B0'='#F3B5B0';'F5F7FA'='#E9EDF2';'F6F8FB'='#F6F8FB';'FFF7F6'='#FFF7F6'
        'FFFFFF'='#FFFFFF'
    }
    $dark=@{
        '003399'='#D4E6FF';'0078D7'='#64B5F6';'0645C0'='#7AB6FF';'0F54B6'='#4C91EE';'1463D6'='#69A7FF'
        '16794A'='#6FD6A0';'17263C'='#E8EDF5';'28384D'='#D5DDE8';'536174'='#AFBAC9';'5D6B7E'='#A0ACBC'
        'A96500'='#F1B75B';'A9C7F5'='#35659A';'B42318'='#FF8E88';'B8C0CC'='#707B8A';'CFE8FA'='#30465C'
        'D7DFE9'='#394454';'D9DEE7'='#394454';'E5E9F0'='#303946';'EAF2FF'='#26364A';'EEF1F5'='#303946'
        'EEF3FA'='#303B4A';'F3B5B0'='#75403F';'F5F7FA'='#171A21';'F6F8FB'='#252C37';'FFF7F6'='#382727'
        'FFFFFF'='#222833'
    }
    $palette=if($Theme -eq 'Dark'){$dark}else{$light}
    $TargetWindow.Resources['ThemeColor_WarningBackground']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#493A1F'}else{'#FFF4D6'}))
    $TargetWindow.Resources['ThemeColor_WarningText']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#FFDF9B'}else{'#714A00'}))
    $TargetWindow.Resources['InputBorder']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#99A9BC'}else{'#8592A3'}))
    $TargetWindow.Resources['RowHover']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#303B4A'}else{'#F1F5FA'}))
    $TargetWindow.Resources['RowSelected']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#30465C'}else{'#DCEAFE'}))
    $TargetWindow.Resources['RowAlternate']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#252D38'}else{'#F7F9FC'}))
    $TargetWindow.Resources['AddedBackground']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#214B38'}else{'#DCFCE7'}))
    $TargetWindow.Resources['ResultBackground']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#203E31'}else{'#E9F8EE'}))
    $TargetWindow.Resources['PrimaryBackground']=[Windows.Media.BrushConverter]::new().ConvertFromString($(if($Theme -eq 'Dark'){'#2F6FE4'}else{'#1463D6'}))
    $TargetWindow.Resources['PrimaryForeground']=[Windows.Media.Brushes]::White
    foreach($key in $palette.Keys){
        $TargetWindow.Resources["ThemeColor_$key"]=[Windows.Media.BrushConverter]::new().ConvertFromString($palette[$key])
    }
    if($TargetWindow -eq $window){
            $modeLabel=if($Theme -eq 'Dark'){'Light mode'}else{'Dark mode'}
            $modeToolTip="Appearance: $($script:themePreference) ($Theme). Choose System, Light, or Dark."
            $DarkModeButton.Content=[string]$(if($Theme -eq 'Dark'){[char]0xE708}else{[char]0xE706})
            [Windows.Automation.AutomationProperties]::SetName($DarkModeButton,(Get-LocalizedText $modeLabel))
            $DarkModeButton.ToolTip=(Get-LocalizedText 'Appearance') + ': ' + (Get-LocalizedText $script:themePreference) + ' · ' + (Get-LocalizedText $Theme)
        $script:theme=$Theme
        Set-NativeTitleBarTheme
        if(Get-Command Update-FilterButtons -ErrorAction SilentlyContinue){Update-FilterButtons}
    }
}

function Set-NativeTitleBarTheme {
    if(-not ('GomDwmThemeApi' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class GomDwmThemeApi
{
    [DllImport("dwmapi.dll")]
    public static extern int SetWindowAttribute(IntPtr window, int attribute, ref int value, int valueSize);
}
'@ -ErrorAction Stop
    }
    $handle=[Windows.Interop.WindowInteropHelper]::new($window).Handle
    if($handle -eq [IntPtr]::Zero){return}
    $darkMode=[int]($script:theme -eq 'Dark')
    try {
        $result=[GomDwmThemeApi]::SetWindowAttribute($handle,20,[ref]$darkMode,4)
        if($result -lt 0){[void][GomDwmThemeApi]::SetWindowAttribute($handle,19,[ref]$darkMode,4)}
        $captionColor=if($darkMode){0x211A17}else{0xF2EDE9}
        [void][GomDwmThemeApi]::SetWindowAttribute($handle,35,[ref]$captionColor,4)
    } catch [DllNotFoundException] {
    } catch [EntryPointNotFoundException] {
    }
}

$script:currentProfile='BSC'
$script:isUpdatingLanguage=$false
$script:lastStatusText='Ready'
$script:deliveryCompleted=$false
$script:lastDeliveredSelection=''
$script:gitCheckoutConfirmed=$false
$script:items=New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$script:viewItems=New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$script:knownSources=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$script:db=[pscustomobject]@{User='HOSTBVSFUND';Password='HOST';Tns='FLEX_236';Log='D:/log.txt'}
$script:sqlDefaultApplied=$false
$script:allBranches=@()
$script:isFilteringBranches=$false
$script:searchTimer=New-Object Windows.Threading.DispatcherTimer;$script:searchTimer.Interval=[TimeSpan]::FromMilliseconds(300)
$script:destinationTimer=New-Object Windows.Threading.DispatcherTimer;$script:destinationTimer.Interval=[TimeSpan]::FromMilliseconds(350)
$script:backgroundOperation=$null
$script:backgroundPool=$null
$script:backgroundTimer=New-Object Windows.Threading.DispatcherTimer
$script:backgroundTimer.Interval=[TimeSpan]::FromMilliseconds(80)
$script:backgroundIdleTimer=New-Object Windows.Threading.DispatcherTimer
$script:backgroundIdleTimer.Interval=[TimeSpan]::FromSeconds(15)
function Release-IdleBackgroundPool {
    $script:backgroundIdleTimer.Stop()
    if(-not $script:backgroundOperation -and $script:backgroundPool){$script:backgroundPool.Close();$script:backgroundPool.Dispose();$script:backgroundPool=$null}
}
$script:backgroundIdleTimer.Add_Tick({Release-IdleBackgroundPool})

function Start-DeliveryBackground {
    param([string]$Name,[scriptblock]$Work,[object[]]$Arguments,[object]$Context,[scriptblock]$Success,[scriptblock]$Failure,[scriptblock]$Finally)
    if($script:backgroundOperation){throw 'Another operation is still running.'}
    $script:backgroundIdleTimer.Stop()
    $worker=[PowerShell]::Create()
    try {
        if(-not $script:backgroundPool){
            $script:backgroundPool=[Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,1)
            $script:backgroundPool.Open()
        }
        $worker.RunspacePool=$script:backgroundPool
        [void]$worker.AddScript($Work.ToString())
        foreach($argument in $Arguments){[void]$worker.AddArgument($argument)}
        $async=$worker.BeginInvoke()
        $script:backgroundOperation=[pscustomobject]@{Name=$Name;Worker=$worker;Async=$async;Context=$Context;Success=$Success;Failure=$Failure;Finally=$Finally}
        $script:backgroundTimer.Start()
    } catch {$worker.Dispose();if($script:backgroundPool){$script:backgroundIdleTimer.Start()};throw}
}

function Complete-DeliveryBackground {
    $operation=$script:backgroundOperation
    if(-not $operation -or -not $operation.Async.IsCompleted){return}
    $script:backgroundTimer.Stop();$script:backgroundOperation=$null
    try {
        $result=@($operation.Worker.EndInvoke($operation.Async))
        if($operation.Worker.HadErrors){throw ($operation.Worker.Streams.Error[0].ToString())}
        & $operation.Success $operation.Context $result
    } catch {
        & $operation.Failure $operation.Context $_
    } finally {
        $operation.Worker.Dispose()
        & $operation.Finally $operation.Context
        if(-not $script:backgroundOperation -and $script:backgroundPool){$script:backgroundIdleTimer.Start()}
    }
}
$script:backgroundTimer.Add_Tick({Complete-DeliveryBackground})
$window.Add_Closing({param($sender,$eventArgs)
    $copy=Get-Variable -Name copyJob -Scope Script -ErrorAction SilentlyContinue
    if($copy -and $copy.Value -and $copy.Value.State -eq 'Running'){$eventArgs.Cancel=$true;[void][Windows.MessageBox]::Show($window,(Get-LocalizedText 'Delivery is still running. Cancel it and wait before closing.'),'Delivery in progress');return}
    if($script:backgroundOperation){$eventArgs.Cancel=$true;[void][Windows.MessageBox]::Show($window,(Get-LocalizedText 'An operation is still running. Please wait for it to finish before closing.'),(Get-LocalizedText 'Operation in progress'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Information)}
})
$window.Add_Closed({
    $script:backgroundIdleTimer.Stop()
    if($script:backgroundPool){$script:backgroundPool.Close();$script:backgroundPool.Dispose();$script:backgroundPool=$null}
    foreach($name in @('runAllOutputPath','runAllErrorPath')){
        $var=Get-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue
        if($var -and $var.Value){Remove-Item -LiteralPath $var.Value -Force -ErrorAction SilentlyContinue}
    }
})

$FileGrid.ItemsSource=$script:viewItems
$DuplicateMode.SelectedIndex=1
$AutoCheckoutAndPull.Visibility='Collapsed'
$IncludeWorkspace.Visibility='Collapsed'
$CollectHint.TextWrapping='Wrap';$PasteResult.TextWrapping='Wrap';$DestinationError.TextWrapping='Wrap'
$Step1Button.TabIndex=1;$Step2Button.TabIndex=2;$Step3Button.TabIndex=3;$AdvancedCollect.TabIndex=12
$SelectAllButton.TabIndex=42;$ClearSelectionButton.TabIndex=43;$SortAscendingButton.TabIndex=44
$SortDescendingButton.TabIndex=45;$SortSqlFlexButton.TabIndex=46;$RemoveSelectedButton.TabIndex=47
$ContinueButton.TabIndex=48;$BackToReviewButton.TabIndex=49;$CancelDeliveryButton.TabIndex=57
$OpenDestinationButton.TabIndex=58;$OpenManifestButton.TabIndex=59;$ReviewErrorsButton.TabIndex=60
[Windows.Controls.ToolTipService]::SetShowOnDisabled($Step2Button,$true);[Windows.Controls.ToolTipService]::SetShowOnDisabled($Step3Button,$true)

function Format-FileCount([int]$Count) {
    if($script:language -eq 'Vietnamese'){return "$Count file"}
    Get-LocalizedText ("{0} file{1}" -f $Count, $(if($Count -eq 1){''}else{'s'}))
}

function Set-Status([string]$Text,[string]$Color='#1463D6'){
    $script:lastStatusText=$Text
    if($script:theme -eq 'Dark'){
        $Color=switch($Color.ToUpperInvariant()){
            '#1463D6'{'#69A7FF'}
            '#16794A'{'#6FD6A0'}
            '#B42318'{'#FF8E88'}
            '#A96500'{'#F1B75B'}
            default{$Color}
        }
    }
    $InlineStatus.Text=Get-LocalizedText $Text
    $InlineStatus.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

function Get-SelectedItems{ return @($script:items | Where-Object Included) }
function Get-FileType([string]$Path){
    $ext=[IO.Path]::GetExtension($Path).TrimStart('.')
    if(-not $ext){return 'Other'}
    return $ext.ToUpperInvariant()
}

function Convert-UiStatus([string]$Status){
    if($Status -match '^Ready'){return 'Ready'}
    if($Status -match '^Git A'){return 'Added'}
    if($Status -match '^Git D'){return 'Deleted'}
    if($Status -match '^Git'){return 'Modified'}
    if($Status -match '^Copied and verified'){return 'Copied and verified'}
    if($Status -match '^Copied'){return 'Copied'}
    if($Status -match '^Skipped'){return 'Skip'}
    if($Status -match '^Cancelled'){return 'Cancelled'}
    if($Status -match '^(Error|Failed)'){return 'Error: '+($Status -replace '^(Error|Failed):?\s*','')}
    return $Status
}

function Update-StepLabels([int]$Step) {
    $labels=@((Get-LocalizedText '1  Select files'),(Get-LocalizedText "2  Review ($($script:items.Count))"),(Get-LocalizedText '3  Deliver'))
    $buttons=@($Step1Button,$Step2Button,$Step3Button)
    for($i=0;$i -lt 3;$i++){
        $done=($i+1) -lt $Step;$current=($i+1) -eq $Step
        $mark=if($done){[string][char]0x2713}else{[string]($i+1)}
        $panel=New-Object Windows.Controls.StackPanel;$panel.Orientation='Horizontal'
        $badge=New-Object Windows.Controls.Border;$badge.Width=20;$badge.Height=20;$badge.CornerRadius=[Windows.CornerRadius]::new(10);$badge.BorderThickness=[Windows.Thickness]::new(1)
        $badge.Background=if($done -or $current){$window.Resources['PrimaryBackground']}else{[Windows.Media.Brushes]::Transparent}
        $badge.BorderBrush=if($done -or $current){$window.Resources['PrimaryBackground']}else{$window.Resources['InputBorder']}
        $number=New-Object Windows.Controls.TextBlock;$number.Text=$mark;$number.FontSize=12;$number.FontWeight=[Windows.FontWeights]::SemiBold;$number.HorizontalAlignment='Center';$number.VerticalAlignment='Center'
        $number.Foreground=if($done -or $current){[Windows.Media.Brushes]::White}else{$window.Resources['ThemeColor_5D6B7E']};$badge.Child=$number
        $caption=New-Object Windows.Controls.TextBlock;$caption.Text=$labels[$i].Substring(1).Trim();$caption.Margin=[Windows.Thickness]::new(7,0,0,0);$caption.VerticalAlignment='Center'
        [void]$panel.Children.Add($badge);[void]$panel.Children.Add($caption);$buttons[$i].Content=$panel
        [Windows.Automation.AutomationProperties]::SetName($buttons[$i],$labels[$i])
    }
}

function Set-Step([int]$Step){
    $script:currentStep=$Step
    $CollectScroll.Visibility=if($Step -eq 1){'Visible'}else{'Collapsed'}
    $CollectView.Visibility=if($Step -eq 1){'Visible'}else{'Collapsed'}
    $ReviewView.Visibility=if($Step -eq 2){'Visible'}else{'Collapsed'}
    $DeliverScroll.Visibility=if($Step -eq 3){'Visible'}else{'Collapsed'}
    $DeliverView.Visibility=if($Step -eq 3){'Visible'}else{'Collapsed'}
    $DeliverContainer.Visibility=if($Step -eq 3){'Visible'}else{'Collapsed'}
    $AddGitChangesButton.IsDefault=($Step -eq 1);$ContinueButton.IsDefault=($Step -eq 2);$StartDeliveryButton.IsDefault=($Step -eq 3 -and -not $script:deliveryCompleted);$OpenDestinationButton.IsDefault=($Step -eq 3 -and $script:deliveryCompleted)
    if($window.IsVisible){
        $activeView=if($Step -eq 1){$CollectScroll}elseif($Step -eq 2){$ReviewView}else{$DeliverContainer}
        $fade=New-Object Windows.Media.Animation.DoubleAnimation
        $fade.From=0.94;$fade.To=1.0;$fade.Duration=[Windows.Duration]::new([TimeSpan]::FromMilliseconds(120))
        $activeView.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
    }
    if($Step -eq 3){Set-Status 'Ready to deliver';Update-DestinationState}
    Update-StepLabels $Step
    foreach($pair in @(@($Step1Button,1),@($Step2Button,2),@($Step3Button,3))){
        $pair[0].Background=if($pair[1] -eq $Step){$window.Resources['ThemeColor_FFFFFF']}else{[Windows.Media.Brushes]::Transparent}
        $pair[0].Foreground=if(-not $pair[0].IsEnabled){$window.Resources['ThemeColor_B8C0CC']}elseif($pair[1] -eq $Step){$window.Resources['ThemeColor_1463D6']}else{$window.Resources['ThemeColor_28384D']}
        $pair[0].BorderThickness=if($pair[1] -eq $Step){[Windows.Thickness]::new(1)}else{[Windows.Thickness]::new(0)}
        $pair[0].BorderBrush=if($pair[1] -eq $Step){$window.Resources['ThemeColor_D7DFE9']}else{[Windows.Media.Brushes]::Transparent}
        $pair[0].FontWeight=if($pair[1] -eq $Step){[Windows.FontWeights]::SemiBold}else{[Windows.FontWeights]::Normal}
    }
}

function Set-DeliveryProfile([string]$Profile, [bool]$UpdateDbDefaults=$true) {
    $script:currentProfile = $Profile
    if ($Profile -eq 'BVSC') {
        if ($ProjectProfileCombo.SelectedIndex -ne 0) { $ProjectProfileCombo.SelectedIndex = 0 }
        if ($UpdateDbDefaults) {
            $script:db.User = 'HOSTBVSFUND'
            $script:db.Password = 'HOST'
            $script:db.Tns = 'FLEX_236'
        }
        $ProfileDeliveryHint.Text = Get-LocalizedText "BVSC structure $([char]0x00B7) install.sql and runscript.txt $([char]0x00B7) No manifest"
        $SqlScriptDescription.Text = ''
    } else {
        if ($ProjectProfileCombo.SelectedIndex -ne 1) { $ProjectProfileCombo.SelectedIndex = 1 }
        if ($UpdateDbDefaults) {
            $script:db.User = 'HOSTBSCFUND'
            $script:db.Password = 'HOST'
            $script:db.Tns = 'FLEX189'
        }
        $ProfileDeliveryHint.Text = Get-LocalizedText "Keeps repo structure $([char]0x00B7) runscript.txt $([char]0x00B7) No manifest"
        $SqlScriptDescription.Text = ''
    }
    $SqlConfigSummary.Text = Get-LocalizedText ("DB: {0}@{1}" -f $script:db.User,$script:db.Tns)
    $OpenManifestButton.Visibility = 'Collapsed'

    # Recompute relative path for existing items
    foreach ($item in $script:items) {
        $srcRoot = if ($item.PSObject.Properties['SourceRoot'] -and $item.SourceRoot) { $item.SourceRoot } else { $RepoPath.Text.Trim() }
        $preserve = if ($item.PSObject.Properties['PreserveStructure']) { $item.PreserveStructure } else { $true }
        $item.Relative = Get-DeliveryRelativePath -Source $srcRoot -Path $item.Source -PreserveStructure $preserve -Profile $script:currentProfile
        if($item.PSObject.Properties['PackageDirectory']) { $dir=[IO.Path]::GetDirectoryName($item.Relative);$item.PackageDirectory=if($dir){$dir+'\'}else{''};$item.PackageName=[IO.Path]::GetFileName($item.Relative) }
    }
    Update-Ui
}

function Show-StartupProfileDialog {
    $sx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Select Delivery Project Mode" Width="540" Height="340" ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
    Background="#F5F7FA" Foreground="#28384D" FontFamily="Segoe UI Variable, Segoe UI">
    <Window.Resources>
        <Style TargetType="{x:Type Control}"><Setter Property="FocusVisualStyle" Value="{x:Null}"/></Style>
        <Style x:Key="ProfileCard" TargetType="Button">
            <Setter Property="Background" Value="White"/><Setter Property="BorderBrush" Value="#D7DFE9"/><Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="18"/><Setter Property="Cursor" Value="Hand"/><Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#1463D6"/><Setter TargetName="bd" Property="Background" Value="#F0F7FF"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value=".85"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <StackPanel>
            <TextBlock Text="Choose Delivery Project Profile" FontSize="18" FontWeight="SemiBold" Foreground="#17263C"/>
            <TextBlock Text="Select how delivery package paths and deployment scripts should be formatted:" Margin="0,4,0,16" Foreground="#5D6B7E"/>
        </StackPanel>
        <Grid Grid.Row="1">
            <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="12"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <Button x:Name="BvscOption" Style="{StaticResource ProfileCard}" Grid.Row="0">
                <StackPanel>
                    <TextBlock Text="BVSC (Bao Viet Securities)" FontSize="15" FontWeight="SemiBold" Foreground="#1463D6"/>
                    <TextBlock Text="Organizes into 2.HOST\upgrade\sql\2.HOST. Creates runUpdate.bat, setVariable.bat, and install.sql." Margin="0,3,0,0" Foreground="#5D6B7E" TextWrapping="Wrap"/>
                </StackPanel>
            </Button>
            <Button x:Name="OtherOption" Style="{StaticResource ProfileCard}" Grid.Row="2">
                <StackPanel>
                    <TextBlock Text="Other" FontSize="15" FontWeight="SemiBold" Foreground="#17263C"/>
                    <TextBlock Text="Preserves the repository structure and generates runscript.txt with absolute local-repository SQL paths. Does not create runscript.sql or a delivery manifest." Margin="0,3,0,0" Foreground="#5D6B7E" TextWrapping="Wrap"/>
                </StackPanel>
            </Button>
        </Grid>
        <TextBlock Grid.Row="2" Text="You can also switch profiles anytime at the top bar." Margin="0,14,0,0" Foreground="#8C98A8" FontSize="11" HorizontalAlignment="Center"/>
    </Grid>
</Window>
'@
    $sx=[regex]::Replace($sx,'#([0-9A-Fa-f]{6})','{DynamicResource ThemeColor_$1}')
    $sx=$sx.Replace('Value="White"','Value="{DynamicResource ThemeColor_FFFFFF}"')
    [xml]$sx=$sx
    $dlg=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $sx))
    Set-Theme $script:theme $dlg
    Set-WindowLanguage $dlg
    if ($window.IsVisible) { $dlg.Owner = $window }
    $bvscBtn=$dlg.FindName('BvscOption')
    $otherBtn=$dlg.FindName('OtherOption')
    $bvscBtn.Add_Click({ Set-DeliveryProfile 'BVSC'; $dlg.Close() })
    $otherBtn.Add_Click({ Set-DeliveryProfile 'BSC'; $dlg.Close() })
    [void]$dlg.ShowDialog()
}

function Update-Ui([bool]$RefreshGrid=$true) {
    $selected=@(Get-SelectedItems);[long]$bytes=0;foreach($i in $selected){$bytes+=[long]$i.Size}
    $statusTextCache=@{};$resultTextCache=@{}
    foreach($item in $script:items){
        $statusKey=[string]$item.Status
        if(-not $statusTextCache.ContainsKey($statusKey)){$statusTextCache[$statusKey]=Get-LocalizedText $statusKey}
        $item.StatusLabel=$statusTextCache[$statusKey]
        if($item.DeliveryResult){$resultKey=[string]$item.DeliveryResult;if(-not $resultTextCache.ContainsKey($resultKey)){$mark=if($resultKey -in @('Verified','Copied')){[char]0x2713}elseif($resultKey -eq 'Failed'){[char]0x2715}else{[char]0x26A0};$resultTextCache[$resultKey]="$mark $(Get-LocalizedText $resultKey)"};$item.DeliveryResultLabel=$resultTextCache[$resultKey]}
    }
    if($script:deliveryCompleted -and ((@($selected|ForEach-Object {$_.Source}) -join "`n") -ne $script:lastDeliveredSelection)){Reset-DeliveryPresentation}
    $sql=(@($selected | Where-Object {[IO.Path]::GetExtension($_.Relative).Equals('.sql',[StringComparison]::OrdinalIgnoreCase)})).Count
    $Step2Button.IsEnabled=($script:items.Count -gt 0)
    $currentStepVar=Get-Variable -Name currentStep -Scope Script -ErrorAction SilentlyContinue
    if($currentStepVar){Update-StepLabels $currentStepVar.Value}
    $Step3Button.IsEnabled=($selected.Count -gt 0)
    $Step2Button.ToolTip=if($Step2Button.IsEnabled){$null}else{'Add at least one file to review.'}
    $Step3Button.ToolTip=if($Step3Button.IsEnabled){$null}else{'Include at least one file to continue to delivery.'}
    $ReviewSummary.Text=Get-LocalizedText ("{0} of {1} included {4} {2} {4} {3} SQL" -f $selected.Count,$script:items.Count,(Format-DeliverySize $bytes),$sql,[char]0x00B7)
    $RemoveSelectedButton.Content=Get-LocalizedText ("Remove {0} from list" -f $selected.Count)
    $ContinueButton.Content=Get-LocalizedText ('Continue ('+(Format-FileCount $selected.Count)+')')
    $ContinueButton.IsEnabled=($selected.Count -gt 0)
    $DeliverTitle.Text=Get-LocalizedText ("Deliver {0} {2} {1}" -f (Format-FileCount $selected.Count),(Format-DeliverySize $bytes),[char]0x00B7)
    $DeliverSummary.Text=''
    $SqlOptions.Visibility=if($sql){'Visible'}else{'Collapsed'}
    $EmptyState.Visibility=if($script:items.Count){'Collapsed'}else{'Visible'}
    if($sql -and -not $script:sqlDefaultApplied){$CreateRunScript.IsChecked=$true;$script:sqlDefaultApplied=$true}
    if(-not $sql){$script:sqlDefaultApplied=$false}
    $stepVar=Get-Variable -Name currentStep -Scope Script -ErrorAction SilentlyContinue
    if($stepVar -and $stepVar.Value -eq 3){Update-DestinationState}
    if($RefreshGrid){Refresh-Grid}
}

function Reset-DeliveryPresentation {
    $script:deliveryCompleted=$false
    $StartDeliveryButton.Content=Get-LocalizedText 'Start delivery'
    $StartDeliveryButton.Style=$window.Resources['Primary']
    $StartDeliveryButton.IsDefault=($script:currentStep -eq 3)
    $OpenDestinationButton.IsDefault=$false
    $OpenDestinationButton.Style=$window.Resources['Secondary']
    $ResultPanel.Visibility='Collapsed'
}

function Refresh-Grid {
    $query=$SearchBox.Text.Trim()
    $filter=$FilterBox.SelectedIndex
    $script:viewItems.Clear()
    foreach($item in $script:items){
        $ok=([string]::IsNullOrWhiteSpace($query) -or $item.FileName.IndexOf($query,[StringComparison]::OrdinalIgnoreCase)-ge 0 -or $item.Source.IndexOf($query,[StringComparison]::OrdinalIgnoreCase)-ge 0 -or $item.Relative.IndexOf($query,[StringComparison]::OrdinalIgnoreCase)-ge 0)
        if($ok){
            switch($filter){
                1{$ok=$item.Included}
                2{$ok=-not $item.Included}
                3{$ok=[IO.Path]::GetExtension($item.Relative).Equals('.sql',[StringComparison]::OrdinalIgnoreCase)}
                4{$ok=$item.DeliveryResult -eq 'Failed'}
            }
        }
        if($ok){[void]$script:viewItems.Add($item)}
    }
    $ToggleFilteredButton.IsChecked=($script:viewItems.Count -gt 0 -and @($script:viewItems|Where-Object {-not $_.Included}).Count -eq 0)
    $FileGrid.Items.Refresh()
}

function Update-BranchSuggestions {
    param([Parameter(Mandatory)][Windows.Controls.ComboBox]$Combo)
    if($script:isFilteringBranches){return}
    $query=$Combo.Text.Trim()
    $matches=if([string]::IsNullOrWhiteSpace($query)){
        @($script:allBranches)
    }else{
        @($script:allBranches | Where-Object { $_.IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
    }
    # Master-related branches are operationally important, so keep every
    # branch containing "master" visible even while the user types a filter.
    $masterRelated=@($script:allBranches | Where-Object { $_.IndexOf('master',[StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if($masterRelated.Count){
        $matches=@($masterRelated + $matches)
        # Remove duplicated entries while preserving the master-related branches first.
        $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $matches=@($matches | Where-Object { $seen.Add($_) })
    }
    $script:isFilteringBranches=$true
    try {
        [void]($Combo.ItemsSource=$matches)
        [void]($Combo.Text=$query)
        if($Combo.IsKeyboardFocusWithin -and $query){[void]($Combo.IsDropDownOpen=$true)}
    } finally {
        $script:isFilteringBranches=$false
    }
}

function Enable-BranchTypingSearch {
    param([Parameter(Mandatory)][Windows.Controls.ComboBox]$Combo)
    [void]($Combo.IsTextSearchEnabled=$false)
    [void]($Combo.StaysOpenOnEdit=$true)
    [void]$Combo.ApplyTemplate()
    $editor=$Combo.Template.FindName('PART_EditableTextBox',$Combo)
    if($editor -and -not ($editor.Tag -is [Windows.Controls.ComboBox])){
        [void]($editor.Tag=$Combo)
        $editor.Add_TextChanged({param($sender,$eventArgs)Update-BranchSuggestions -Combo $sender.Tag})
        $Combo.Add_DropDownOpened({param($sender,$eventArgs)Update-BranchSuggestions -Combo $sender})
    }
}

function Update-DestinationState {
    $root=$DestinationPath.Text.Trim();$selected=@(Get-SelectedItems)
    $StartDeliveryButton.IsEnabled=$false
    $DeliveryReadyHint.Text=Get-LocalizedText 'Select a destination to continue.'
    if($script:backgroundOperation -and $script:backgroundOperation.Name -eq 'SQL execution'){$DeliveryReadyHint.Text=Get-LocalizedText 'Wait for SQL execution to finish.';return}
    if(-not $root){$DestinationInfo.Text='';$ConflictInfo.Text='';return}
    try { $dest=Get-DeliveryDestination -Root $root -BranchName $CompareBranch.Text -UseBranchFolder ([bool]$BranchDestination.IsChecked) }
    catch { $DestinationInfo.Text=$_.Exception.Message;$DestinationInfo.Foreground=$window.Resources['ThemeColor_A96500'];$ConflictInfo.Text='';return }
    try { if(-not [IO.Path]::IsPathRooted($dest)){throw 'Use an absolute destination path.'};[void][IO.Path]::GetFullPath($dest);if(Test-Path -LiteralPath $dest -PathType Leaf){throw 'Destination is an existing file.'} }
    catch { $DestinationInfo.Text=$_.Exception.Message;$DestinationInfo.Foreground=$window.Resources['ThemeColor_A96500'];$ConflictInfo.Text='';return }
    $job=Get-Variable -Name copyJob -Scope Script -ErrorAction SilentlyContinue
    if($selected.Count -and (-not $job -or -not $job.Value -or $job.Value.State -in @('Completed','Failed','Stopped'))){$StartDeliveryButton.IsEnabled=$true;$DeliveryReadyHint.Text=''}
    elseif(-not $selected.Count){$DeliveryReadyHint.Text=Get-LocalizedText 'Include at least one file to start.'}
    if(-not (Test-Path -LiteralPath $dest -PathType Container)){$DestinationInfo.Text=Get-LocalizedText ("Delivery folder: {0} (will be created after confirmation)." -f $dest);$DestinationInfo.Foreground=$window.Resources['ThemeColor_A96500'];$ConflictInfo.Text='';return}
    $DestinationInfo.Text=Get-LocalizedText ("Delivery folder: {0}" -f $dest);$DestinationInfo.Foreground=$window.Resources['ThemeColor_5D6B7E']
    $conflicts=@($selected|Where-Object {Test-Path -LiteralPath (Join-Path $dest $_.Relative)}).Count
    $ConflictInfo.Text=if($conflicts){$action=@('skipped','overwritten','renamed')[$DuplicateMode.SelectedIndex];Get-LocalizedText ("{0} of {1} selected files already exist; {2} will be {3}." -f $conflicts,$selected.Count,$conflicts,$action)}else{Get-LocalizedText 'No selected files currently exist in this folder.'}
}

function Update-GitWorkspaceInfo([string]$Repository) {
    $branch=Invoke-DeliveryGitRaw $Repository @('branch','--show-current')
    $state=Invoke-DeliveryGitRaw $Repository @('status','--porcelain=v1','--untracked-files=no')
    if($branch.ExitCode -ne 0 -or $state.ExitCode -ne 0){$GitWorkspaceInfo.Text=Get-LocalizedText 'Unable to read current Git workspace state.';return}
    $name=if($branch.Output.Count){$branch.Output[0]}else{'detached HEAD'}
    Set-GitWorkspaceInfo $name (@($state.Output).Count)
}

function Set-GitWorkspaceInfo([string]$name,[int]$count) {
    $description=if($count){"$count tracked change(s); resolve before comparing"}else{'clean'}
    $GitWorkspaceInfo.Text="Current: $name $([char]0x00B7) Working tree: $description"
    $GitWorkspaceInfo.Foreground=if($count){$window.Resources['ThemeColor_A96500']}else{$window.Resources['ThemeColor_16794A']}
    $GitDirtyWarning.Visibility=if($count){'Visible'}else{'Collapsed'}
}

function Set-GitControlsBusy([bool]$Busy) {
    $RepoPath.IsEnabled=-not $Busy;$ChooseRepoButton.IsEnabled=-not $Busy
    $AdvancedCollect.IsEnabled=-not $Busy;$ProjectProfileCombo.IsEnabled=-not $Busy
    $LoadBranchesButton.IsEnabled=-not $Busy
    $BaseBranch.IsEnabled=(-not $Busy -and $script:allBranches.Count -gt 0)
    $CompareBranch.IsEnabled=(-not $Busy -and $script:allBranches.Count -gt 0)
    $AddGitChangesButton.IsEnabled=(-not $Busy -and $script:allBranches.Count -gt 0)
    $CollectProgress.Visibility=if($Busy){'Visible'}else{'Collapsed'}
}

function Sort-ReviewItems([bool]$Descending) {
    $ordered=@($script:items | Sort-Object -Property Relative -Descending:$Descending)
    $script:items.Clear()
    foreach($item in $ordered){[void]$script:items.Add($item)}
    Refresh-Grid
    $sortHint=if($Descending){'Sorted Z to A.'}else{'Sorted A to Z.'}
    $ReviewActionHint.Text=Get-LocalizedText $sortHint
}

function Sort-ReviewItemsFlexDb {
    $ordered=@($script:items | Sort-Object -Property { Get-DeliverySqlPriority $_.Relative }, { $_.Relative })
    $script:items.Clear()
    foreach($item in $ordered){[void]$script:items.Add($item)}
    Refresh-Grid
    $ReviewActionHint.Text=''
}

function Add-Items([object[]]$Files,[hashtable]$GitStatus=@{},[string]$SourceRoot=$null,[hashtable]$GitMetadata=@{}) {
    $added=0;$duplicates=0
    $root=if($SourceRoot){$SourceRoot}elseif($RepoPath.Text.Trim()){$RepoPath.Text.Trim()}else{''}
    foreach($file in $Files){
        if(-not $file){continue}
        if(-not $script:knownSources.Add($file.FullName)){$duplicates++;continue}
        $git=if($GitStatus.ContainsKey($file.FullName)){$GitStatus[$file.FullName]}else{$null}
        $item=New-DeliveryItem -File $file -Source $root -PreserveStructure $true -GitStatus $git -Profile $script:currentProfile
        $item.Status=Convert-UiStatus $item.Status
        $item|Add-Member NoteProperty FileName ([IO.Path]::GetFileName($file.FullName))
        $item|Add-Member NoteProperty SourceFolder (Split-Path $file.FullName -Parent)
        $item|Add-Member NoteProperty FileType (Get-FileType $file.FullName)
        $dir=[IO.Path]::GetDirectoryName($item.Relative)
        $item|Add-Member NoteProperty PackageDirectory $(if($dir){$dir+'\'}else{''})
        $item|Add-Member NoteProperty PackageName ([IO.Path]::GetFileName($item.Relative))
        $item|Add-Member NoteProperty GitDiff $(if($GitMetadata.ContainsKey($file.FullName)){$GitMetadata[$file.FullName]}else{$null})
        $scriptSource=$file.FullName
        if($item.GitDiff){
            $repoRoot=[IO.Path]::GetFullPath($item.GitDiff.Repository).TrimEnd('\','/')+'\'
            $scriptSource=[IO.Path]::GetFullPath((Join-Path $repoRoot $item.GitDiff.ComparePath))
            if(-not $scriptSource.StartsWith($repoRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Git file path is outside the repository.'}
        }
        $item|Add-Member NoteProperty ScriptSource $scriptSource
        [void]$script:items.Add($item)
        $added++
    }
    Update-Ui
    return [pscustomobject]@{Added=$added;Duplicates=$duplicates}
}

function Start-DeliveryDiffViewer([string]$Tool,[object[]]$Arguments) {
    Start-Process -FilePath $Tool -ArgumentList $Arguments -ErrorAction Stop
}

function Open-DeliveryGitDiff($Item) {
    if($script:backgroundOperation){$ReviewActionHint.Text=Get-LocalizedText 'Another operation is still running.';return}
    try {
        if(-not $Item -or -not $Item.PSObject.Properties['GitDiff'] -or -not $Item.GitDiff){throw 'This file was not added from a Git branch comparison. Compare branches first to view its changes.'}
        $ViewChangesButton.IsEnabled=$false;$ReviewActionHint.Text=Get-LocalizedText 'Preparing Git diff...'
        $work={param($module,$metadata)
            $ErrorActionPreference='Stop';. $module
            $tool=Find-DeliveryTortoiseGitMerge
            if(-not $tool){throw 'TortoiseGitMerge was not found. Install TortoiseGit or add TortoiseGitMerge.exe to PATH.'}
            $files=New-DeliveryGitDiffFiles $metadata
            [pscustomobject]@{Tool=$tool;Arguments=@(Get-DeliveryTortoiseArguments $metadata $files)}
        }
        $success={param($context,$result)
            $data=$result[-1]
            Start-DeliveryDiffViewer $data.Tool $data.Arguments
            $ReviewActionHint.Text=Get-LocalizedText 'Git diff opened.'
        }
        $failure={param($context,$errorRecord)
            $ReviewActionHint.Text=Get-LocalizedText 'Could not open Git diff.'
            [void][Windows.MessageBox]::Show($window,$errorRecord.Exception.Message,'Could not open Git diff',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
        }
        $finally={param($context)
            $selected=$FileGrid.SelectedItem
            $ViewChangesButton.IsEnabled=[bool]($selected -and $selected.PSObject.Properties['GitDiff'] -and $selected.GitDiff)
        }
        Start-DeliveryBackground 'Open Git diff' $work @((Join-Path $script:appRoot 'Core.Git.ps1'),$Item.GitDiff) $null $success $failure $finally
    } catch {
        $ReviewActionHint.Text=Get-LocalizedText 'Could not open Git diff.'
        $selected=$FileGrid.SelectedItem;$ViewChangesButton.IsEnabled=[bool]($selected -and $selected.PSObject.Properties['GitDiff'] -and $selected.GitDiff)
        [void][Windows.MessageBox]::Show($window,$_.Exception.Message,'Could not open Git diff',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    }
}

function Add-DirectPaths([string[]]$Paths,[hashtable]$GitStatus=@{}) {
    $files=New-Object System.Collections.Generic.List[object]
    foreach($path in $Paths){
        if(Test-Path -LiteralPath $path -PathType Leaf){
            $f=Get-Item -LiteralPath $path
            if(-not(Test-DeliveryExcludedPath $f.FullName $ExcludeRules.Text)){[void]$files.Add($f)}
        }elseif(Test-Path -LiteralPath $path -PathType Container){
            Start-FolderScan @($path) $GitStatus
        }
    }
    if($files.Count){return Add-Items -Files @($files.ToArray()) -GitStatus $GitStatus}
    return [pscustomobject]@{Added=0;Duplicates=0}
}

function Start-FolderScan([string[]]$Paths,[hashtable]$GitStatus=@{}) {
    $CollectProgress.Visibility='Visible'
    $CollectHint.Text=Get-LocalizedText 'Scanning files...';Set-Status 'Scanning files...'
    $script:scanGit=$GitStatus;$script:scanRoot=$Paths[0]
    $script:scanJob=Start-Job -ArgumentList (Join-Path $script:appRoot 'Core.FileOps.ps1'),$Paths,$ExcludeRules.Text -ScriptBlock {
        param($m,$p,$rules);. $m;Get-DeliveryFiles -Paths $p -ExcludeRules $rules
    }
    $script:scanTimer=New-Object Windows.Threading.DispatcherTimer
    $script:scanTimer.Interval=[TimeSpan]::FromMilliseconds(150)
    $script:scanTimer.Add_Tick({
        if($script:scanJob.State -notin @('Completed','Failed','Stopped')){return}
        $script:scanTimer.Stop()
        $CollectProgress.Visibility='Collapsed'
        if($script:scanJob.State -ne 'Completed'){Set-Status 'File scan failed. Choose the folder again.' '#B42318';return}
        $files=@(Receive-Job $script:scanJob);Remove-Job $script:scanJob -Force
        $r=Add-Items -Files $files -GitStatus $script:scanGit -SourceRoot $script:scanRoot
        $CollectHint.Text=Get-LocalizedText ('Added '+(Format-FileCount $r.Added)+'.')
        Set-Status ('Added '+(Format-FileCount $r.Added)) '#16794A'
        if($r.Added){Set-Step 2}
    })
    $script:scanTimer.Start()
}

function Add-PastedPaths {
    $valid=New-Object System.Collections.Generic.List[string]
    $invalid=New-Object System.Collections.Generic.List[string]
    foreach($line in ($PasteInput.Text -split "`r?`n")){
        $value=$line.Trim().Trim('"')
        if(-not $value){continue}
        if($value.Contains("`t")){$value=@($value -split "`t"|Where-Object {$_.Trim()}|Select-Object -Last 1).Trim()}
        if(-not [IO.Path]::IsPathRooted($value)){
            $base=if($RepoPath.Text.Trim()){$RepoPath.Text.Trim()}else{''}
            if($base){$value=Join-Path $base $value}
        }
        if(Test-Path -LiteralPath $value){[void]$valid.Add($value)}else{[void]$invalid.Add($value)}
    }
    $r=Add-DirectPaths @($valid)
    $PasteResult.Text=Get-LocalizedText ("Added {0} | {1} invalid paths" -f (Format-FileCount $r.Added),$invalid.Count)
    if($r.Added){$PasteInput.Clear();Set-Status ('Added '+(Format-FileCount $r.Added)) '#16794A';Set-Step 2}
}

function Show-SqlDialog {
    $dx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Configure DB Credentials" Width="500" Height="360" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" FontFamily="Segoe UI"
    Background="#F5F7FA" Foreground="#28384D">
    <Window.Resources>
        <Style TargetType="{x:Type Control}"><Setter Property="FocusVisualStyle" Value="{x:Null}"/><Setter Property="Foreground" Value="#28384D"/></Style>
        <Style TargetType="TextBox"><Setter Property="Background" Value="#FFFFFF"/><Setter Property="BorderBrush" Value="#D7DFE9"/><Setter Property="Foreground" Value="#28384D"/></Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <TextBlock Text="Configure DB Credentials" FontSize="18" FontWeight="SemiBold"/>
        <StackPanel Grid.Row="2"><TextBlock Text="DB user"/><TextBox x:Name="User" Height="34" Margin="0,4,0,0" TabIndex="1"/></StackPanel>
        <StackPanel Grid.Row="4"><TextBlock Text="Password"/><TextBox x:Name="Password" Height="34" Margin="0,4,0,0" TabIndex="2"/></StackPanel>
        <StackPanel Grid.Row="6"><TextBlock Text="TNS name"/><TextBox x:Name="Tns" Height="34" Margin="0,4,0,0" TabIndex="3"/></StackPanel>
        <TextBlock x:Name="DialogError" Grid.Row="7" Foreground="#B42318" Visibility="Collapsed"/>
        <TextBlock Grid.Row="7" Text="These credentials are written to setVariable.bat (BVSC) or runscript.txt (Other)." Margin="0,12,0,0" Foreground="#5D6B7E"/>
        <StackPanel Grid.Row="8" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="Cancel" Content="Cancel" IsCancel="True" Margin="0,0,8,0" Width="80" Height="32"/>
            <Button x:Name="Save" Content="Save for this session" IsDefault="True" Width="140" Height="32"/>
        </StackPanel>
    </Grid>
</Window>
'@
    $dx=[regex]::Replace($dx,'#([0-9A-Fa-f]{6})','{DynamicResource ThemeColor_$1}')
    [xml]$dx=$dx
    $d=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    Set-Theme $script:theme $d
    Set-WindowLanguage $d
    if ($window.IsVisible) { $d.Owner=$window }
    $u=$d.FindName('User');$p=$d.FindName('Password');$t=$d.FindName('Tns');$err=$d.FindName('DialogError')
    $u.Text=$script:db.User;$p.Text=$script:db.Password;$t.Text=$script:db.Tns
    $d.FindName('Save').Add_Click({
    if(-not $u.Text.Trim()){$err.Text=Get-LocalizedText 'DB user is required.';$err.Visibility='Visible';return}
    if(-not $t.Text.Trim()){$err.Text=Get-LocalizedText 'TNS name is required.';$err.Visibility='Visible';return}
        $script:db.User=$u.Text.Trim();$script:db.Password=$p.Text.Trim();$script:db.Tns=$t.Text.Trim()
        $SqlConfigSummary.Text=Get-LocalizedText ("DB: {0}@{1}" -f $script:db.User,$script:db.Tns)
        $d.DialogResult=$true
    })
    [void]$d.ShowDialog()
}

function Show-RunAllDialog {
    param(
        [Parameter(Mandatory)][string]$RunScriptPath,
        [string]$Profile = 'BVSC',
        [string]$Dest = ''
    )
    $dx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Run Deployment Scripts" Width="560" Height="460" ResizeMode="NoResize" WindowStartupLocation="CenterOwner"
    Background="#F5F7FA" Foreground="#28384D" FontFamily="Segoe UI Variable, Segoe UI">
    <Window.Resources>
        <Style TargetType="{x:Type Control}"><Setter Property="FocusVisualStyle" Value="{x:Null}"/><Setter Property="Foreground" Value="#28384D"/></Style>
        <Style TargetType="TextBox"><Setter Property="Background" Value="#FFFFFF"/><Setter Property="BorderBrush" Value="#D7DFE9"/><Setter Property="Foreground" Value="#28384D"/></Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="12"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="10"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="10"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="10"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="10"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Text="Run Deployment Scripts" FontSize="18" FontWeight="SemiBold"/>
        <StackPanel Grid.Row="2">
            <TextBlock Text="Script file (read-only)" Foreground="#5D6B7E" FontSize="11"/>
            <TextBox x:Name="ScriptPath" Height="34" Margin="0,4,0,0" IsReadOnly="True" Background="#E5E9F0"/>
        </StackPanel>
        <StackPanel Grid.Row="4">
            <TextBlock Text="DB user"/>
            <TextBox x:Name="User" Height="34" Margin="0,4,0,0" TabIndex="1"/>
        </StackPanel>
        <StackPanel Grid.Row="6">
            <TextBlock Text="Password"/>
            <TextBox x:Name="Password" Height="34" Margin="0,4,0,0" TabIndex="2"/>
        </StackPanel>
        <StackPanel Grid.Row="8">
            <TextBlock Text="TNS name"/>
            <TextBox x:Name="Tns" Height="34" Margin="0,4,0,0" TabIndex="3"/>
        </StackPanel>
        <TextBlock x:Name="RunError" Grid.Row="10" Foreground="#B42318" Visibility="Collapsed" TextWrapping="Wrap"/>
        <TextBlock Grid.Row="11" Text="Credentials will be updated in setVariable.bat (BVSC) before running." Foreground="#5D6B7E" FontSize="11" VerticalAlignment="Bottom" Margin="0,8,0,0"/>
        <StackPanel Grid.Row="12" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="CancelBtn" Content="Cancel" IsCancel="True" Margin="0,0,8,0" Width="80" Height="32"/>
            <Button x:Name="RunBtn" Content="Run" IsDefault="True" Width="80" Height="32" Background="#1463D6" Foreground="White"/>
        </StackPanel>
    </Grid>
</Window>
'@
    $dx = [regex]::Replace($dx,'#([0-9A-Fa-f]{6})','{DynamicResource ThemeColor_$1}')
    $dx = $dx.Replace('Value="White"','Value="{DynamicResource ThemeColor_FFFFFF}"')
    [xml]$dx = $dx
    $d = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    Set-Theme $script:theme $d
    Set-WindowLanguage $d
    if ($window.IsVisible) { $d.Owner = $window }

    $uScript = $d.FindName('ScriptPath')
    $uUser   = $d.FindName('User')
    $uPass   = $d.FindName('Password')
    $uTns    = $d.FindName('Tns')
    $uErr    = $d.FindName('RunError')

    $uScript.Text  = $RunScriptPath
    $uUser.Text    = $script:db.User
    $uPass.Text    = $script:db.Password
    $uTns.Text     = $script:db.Tns

    $d.FindName('RunBtn').Add_Click({
        $dbUser = $uUser.Text.Trim()
        $dbPass = $uPass.Text.Trim()
        $dbTns  = $uTns.Text.Trim()
        if (-not $dbUser) { $uErr.Text = Get-LocalizedText 'DB user is required.'; $uErr.Visibility = 'Visible'; return }
        if (-not $dbTns)  { $uErr.Text = Get-LocalizedText 'TNS name is required.'; $uErr.Visibility = 'Visible'; return }

        # Save back to session
        $script:db.User     = $dbUser
        $script:db.Password = $dbPass
        $script:db.Tns      = $dbTns
        $SqlConfigSummary.Text = Get-LocalizedText ("DB: {0}@{1}" -f $script:db.User,$script:db.Tns)

        try {
            if ($Profile -eq 'BVSC') {
                # Update setVariable.bat with the (possibly edited) credentials, then run runUpdate.bat
                $upgradeDir = Join-Path $Dest '2.HOST\upgrade'
                $cmdDir     = Join-Path $upgradeDir 'cmd'
                $setBat     = Join-Path $cmdDir 'setVariable.bat'
                if (Test-Path -LiteralPath $setBat) {
                    $setBatContent = @(
                        "rem database user",
                        "set HOST_USER=$dbUser",
                        "set HOST_PASSW_USER=$dbPass",
                        "set FLEX_TNSNAMES=$dbTns",
                        ""
                    )
                    Set-Content -LiteralPath $setBat -Value $setBatContent -Encoding ASCII
                }
                $runBat = Join-Path $cmdDir 'runUpdate.bat'
                if (-not (Test-Path -LiteralPath $runBat)) {
                    throw "runUpdate.bat not found: $runBat"
                }
                Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$runBat`"" -WorkingDirectory $cmdDir
            } else {
                # BSC/Other: run sqlplus directly with the runscript
                $runscript = $RunScriptPath
                if (-not (Test-Path -LiteralPath $runscript)) {
                    throw "Script file not found: $runscript"
                }
                $scriptDir = Split-Path $runscript -Parent
                Start-Process -FilePath 'sqlplus' -ArgumentList "$dbUser/$dbPass@$dbTns @`"$runscript`"" -WorkingDirectory $scriptDir
            }
            $d.DialogResult = $true
        } catch {
            $uErr.Text = "Could not launch: $($_.Exception.Message)"
            $uErr.Visibility = 'Visible'
        }
    })
    [void]$d.ShowDialog()
}

function Confirm-RunAllBeforeDelivery {
    param([string]$Profile = 'BVSC')
    $dx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Run All after delivery" Width="540" Height="500" ResizeMode="NoResize" WindowStartupLocation="CenterOwner"
    Background="#F5F7FA" Foreground="#28384D" FontFamily="Segoe UI Variable, Segoe UI">
    <Window.Resources>
        <Style TargetType="{x:Type Control}"><Setter Property="FocusVisualStyle" Value="{x:Null}"/><Setter Property="Foreground" Value="#28384D"/></Style>
        <Style TargetType="TextBox"><Setter Property="Background" Value="#FFFFFF"/><Setter Property="BorderBrush" Value="#D7DFE9"/><Setter Property="Foreground" Value="#28384D"/></Style>
    </Window.Resources>
    <Grid Margin="24">
        <StackPanel>
            <TextBlock Text="Run All after delivery" FontSize="18" FontWeight="SemiBold"/>
            <TextBlock Text="The package will be created first, then its generated deployment script will be started." Margin="0,4,0,16" Foreground="#5D6B7E" TextWrapping="Wrap"/>
            <TextBlock Text="DB user"/><TextBox x:Name="User" Height="34" Margin="0,4,0,10" TabIndex="1"/>
            <TextBlock Text="Password"/><TextBox x:Name="Password" Height="34" Margin="0,4,0,10" TabIndex="2"/>
            <TextBlock Text="TNS name"/><TextBox x:Name="Tns" Height="34" Margin="0,4,0,10" TabIndex="3"/>
            <TextBlock Text="Spool log path"/><TextBox x:Name="SpoolLog" Height="34" Margin="0,4,0,8" TabIndex="4"/>
            <TextBlock x:Name="DialogError" Foreground="#B42318" Visibility="Collapsed" TextWrapping="Wrap"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
                <Button x:Name="Cancel" Content="Cancel" IsCancel="True" Margin="0,0,8,0" Width="80" Height="32"/>
                <Button x:Name="Confirm" Content="Confirm Run All" IsDefault="True" Width="120" Height="32" Background="#1463D6" Foreground="White"/>
            </StackPanel>
        </StackPanel>
    </Grid>
</Window>
'@
    $dx=[regex]::Replace($dx,'#([0-9A-Fa-f]{6})','{DynamicResource ThemeColor_$1}')
    $dx=$dx.Replace('Value="White"','Value="{DynamicResource ThemeColor_FFFFFF}"')
    [xml]$dx=$dx
    $d=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    Set-Theme $script:theme $d
    Set-WindowLanguage $d
    if($window.IsVisible){$d.Owner=$window}

    $u=$d.FindName('User');$p=$d.FindName('Password');$t=$d.FindName('Tns');$log=$d.FindName('SpoolLog');$err=$d.FindName('DialogError')
    $u.Text=$script:db.User;$p.Text=$script:db.Password;$t.Text=$script:db.Tns;$log.Text=$script:db.Log
    $d.FindName('Confirm').Add_Click({
        if(-not $u.Text.Trim()){$err.Text=Get-LocalizedText 'DB user is required.';$err.Visibility='Visible';return}
        if(-not $t.Text.Trim()){$err.Text=Get-LocalizedText 'TNS name is required.';$err.Visibility='Visible';return}
        if(-not $log.Text.Trim()){$err.Text=Get-LocalizedText 'Spool log path is required.';$err.Visibility='Visible';return}
        $script:db.User=$u.Text.Trim();$script:db.Password=$p.Text.Trim();$script:db.Tns=$t.Text.Trim();$script:db.Log=$log.Text.Trim()
        $SqlConfigSummary.Text=Get-LocalizedText ("DB: {0}@{1} | Spool: {2}" -f $script:db.User,$script:db.Tns,$script:db.Log)
        $d.DialogResult=$true
    })
    return ($d.ShowDialog() -eq $true)
}

function Invoke-RunAll {
    param(
        [Parameter(Mandatory)][string]$RunScriptPath,
        [Parameter(Mandatory)][string]$Profile,
        [Parameter(Mandatory)][string]$Dest
    )
    foreach($item in @(Get-SelectedItems)){
        if($Profile -eq 'BVSC'){break}
        if(-not $item.GitDiff -or [IO.Path]::GetExtension($item.Source) -ine '.sql'){continue}
        if(-not (Test-Path -LiteralPath $item.ScriptSource -PathType Leaf)){
            throw "The SQL file is missing in the original repository: $($item.ScriptSource). Check out the compared branch and try again."
        }
        if((Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $item.ScriptSource -Algorithm SHA256).Hash){
            throw "The SQL file in the original repository differs from the compared version: $($item.ScriptSource). Check out the compared branch and try again."
        }
    }
    if(-not(Test-Path -LiteralPath $RunScriptPath)){throw "Script file not found: $RunScriptPath"}
    if($script:backgroundOperation){throw 'Another operation is still running.'}
    $command=Get-Command 'sqlplus.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if(-not $command){throw 'SQL*Plus was not found. Install Oracle SQL*Plus and add it to PATH.'}
    foreach($name in @('runAllOutputPath','runAllErrorPath')){
        $var=Get-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue
        if($var -and $var.Value){Remove-Item -LiteralPath $var.Value -Force -ErrorAction SilentlyContinue}
    }
    $RunAllPanel.Visibility='Visible';$RunAllStatus.Text=Get-LocalizedText 'Running SQL scripts...';$RunAllProgress.Visibility='Visible'
    $ViewRunLogButton.Visibility='Collapsed';$StartDeliveryButton.IsEnabled=$false
    $work={param($module,$exe,$path,$profile,$user,$password,$tns,$log)
        $ErrorActionPreference='Stop';. $module
        Invoke-DeliverySqlPlusProcess -Executable $exe -ScriptPath $path -Profile $profile -User $user -Password $password -Tns $tns -LogPath $log
    }
    $success={param($context,$data)
        $result=$data[-1];$script:runAllOutputPath=$result.OutputPath;$script:runAllErrorPath=$result.ErrorPath;$script:runAllLogPath=$result.LogPath
        $ViewRunLogButton.Visibility='Visible'
        if($result.Status -eq 'Completed'){$RunAllStatus.Text=Get-LocalizedText 'SQL execution completed. No errors detected in the log.';Set-Status 'SQL execution completed.' '#16794A'}
        elseif($result.Status -eq 'Failed'){$RunAllStatus.Text=Get-LocalizedText ('SQL execution failed. Exit code: {0}. {1}' -f $result.ExitCode,($result.Issues -join ' | '));Set-Status 'SQL execution failed. Review the log.' '#B42318'}
        else {$RunAllStatus.Text=Get-LocalizedText 'SQL process exited, but its log was not updated. Review the output before considering it successful.';Set-Status 'SQL result needs review.' '#A96500'}
    }
    $failure={param($context,$errorRecord)
        $RunAllStatus.Text=Get-LocalizedText ('Could not run SQL: {0}' -f $errorRecord.Exception.Message)
        Set-Status 'SQL execution failed.' '#B42318'
        [void][Windows.MessageBox]::Show($window,$errorRecord.Exception.Message,(Get-LocalizedText 'SQL execution failed'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    }
    $finally={param($context)$RunAllProgress.Visibility='Collapsed';Update-DestinationState}
    try {
        Start-DeliveryBackground -Name 'SQL execution' -Work $work -Arguments @((Join-Path $script:appRoot 'Core.Runner.ps1'),$command.Source,$RunScriptPath,$Profile,$script:db.User,$script:db.Password,$script:db.Tns,$script:db.Log) -Context $null -Success $success -Failure $failure -Finally $finally
    } catch {$RunAllProgress.Visibility='Collapsed';Update-DestinationState;throw}
}

function Start-Delivery {
    if($script:backgroundOperation -and $script:backgroundOperation.Name -eq 'SQL execution'){return}
    $selected=@(Get-SelectedItems);$destinationRoot=$DestinationPath.Text.Trim()
    if(-not $destinationRoot){$DestinationError.Text=Get-LocalizedText 'Choose a destination folder.';$DestinationError.Visibility='Visible';return}
    try { $dest=Get-DeliveryDestination -Root $destinationRoot -BranchName $CompareBranch.Text -UseBranchFolder ([bool]$BranchDestination.IsChecked) }
    catch { $DestinationError.Text=$_.Exception.Message;$DestinationError.Visibility='Visible';return }
    if(-not(Test-Path -LiteralPath $dest -PathType Container)){
        if([Windows.MessageBox]::Show((Get-LocalizedText ("The destination folder does not exist:`n{0}`n`nCreate it and continue?" -f $dest)),(Get-LocalizedText 'Create destination folder'),[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){return}
    }
    if(-not(Test-Path -LiteralPath $dest -PathType Container)){
        try{New-Item -ItemType Directory -Path $dest -Force -ErrorAction Stop|Out-Null}catch{$DestinationError.Text=Get-LocalizedText ("Could not create delivery folder: {0}" -f $_.Exception.Message);$DestinationError.Visibility='Visible';return}
    }
    $DestinationError.Visibility='Collapsed';Update-DestinationState
    $mode=@('Skip','Overwrite','Rename automatically')[$DuplicateMode.SelectedIndex]
    if($mode -eq 'Overwrite'){
        $count=@($selected|Where-Object {Test-Path -LiteralPath (Join-Path $dest $_.Relative)}).Count
        if($count -and [Windows.MessageBox]::Show((Get-LocalizedText ("There are {0} existing destination files. Overwrite them?" -f $count)),(Get-LocalizedText 'Confirm overwrite'),[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){return}
    }
    $verify=[bool]$VerifyHash.IsChecked
    $run=[bool]$CreateRunScript.IsChecked
    $writeManifest=$false
    $script:runAllAfterDelivery=$false
    $SqlConfigError.Visibility='Collapsed'
    if($run){
        $missing=@()
        if(-not $script:db.User.Trim()){$missing+='DB user'}
        if(-not $script:db.Tns.Trim()){$missing+='TNS name'}
        if($missing.Count){$SqlConfigError.Text=Get-LocalizedText ("DB configuration is missing: {0}. Click Configure DB credentials." -f ($missing -join ', '));$SqlConfigError.Visibility='Visible';return}
    }
    $hasSql=@($selected|Where-Object {[IO.Path]::GetExtension($_.Relative).Equals('.sql',[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0
    if($run -and $hasSql){
        $generatedPaths=if($script:currentProfile -eq 'BVSC'){
            @('Huong_dan_cap_nhat.txt','2.HOST\upgrade\Huong dan runall.sql','2.HOST\upgrade\cmd\runUpdate.bat','2.HOST\upgrade\cmd\setVariable.bat','2.HOST\upgrade\sql\install.sql','2.HOST\upgrade\runscript.txt')
        }else{@('runscript.txt')}
        $existingGenerated=@($generatedPaths | ForEach-Object { Join-Path $dest $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
        if($existingGenerated.Count){
            $message="Deployment script generation will overwrite these existing files:`n`n" + ($existingGenerated -join "`n") + "`n`nContinue?"
            if([Windows.MessageBox]::Show((Get-LocalizedText $message),(Get-LocalizedText 'Confirm generated files'),[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){return}
        }
        $answer=[Windows.MessageBox]::Show((Get-LocalizedText 'Do you want to run all deployment scripts after delivery?'),(Get-LocalizedText 'Run All'),[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Question)
        if($answer -eq 'Yes'){
            if(-not (Confirm-RunAllBeforeDelivery -Profile $script:currentProfile)){return}
            $script:runAllAfterDelivery=$true
        }
    }
    $script:deliveryPath=$dest
    $DeliveryOptions.IsEnabled=$false;$DestinationMode.IsEnabled=$false;$DestinationPath.IsEnabled=$false;$ChooseDestinationButton.IsEnabled=$false;$BackToReviewButton.IsEnabled=$false;$StartDeliveryButton.IsEnabled=$false;$CancelDeliveryButton.IsEnabled=$true
    $CancelDeliveryButton.Visibility='Visible';$DeliveryProgress.Visibility='Visible';$DeliveryStatus.Visibility='Visible'
    $DeliveryProgress.Maximum=$selected.Count
    $script:cancelFile=Join-Path ([IO.Path]::GetTempPath())('delivery-copy-'+[Guid]::NewGuid()+'.cancel')
    $jobItems=@($selected|ForEach-Object {[pscustomobject]@{Included=$_.Included;Source=$_.Source;ScriptSource=$_.ScriptSource;Relative=$_.Relative;ActualDestination=$null;Size=$_.Size;SizeDisplay=$_.SizeDisplay;Status=$_.Status;StatusBrush=$_.StatusBrush}})
    $prof=$script:currentProfile
    $u=$script:db.User;$p=$script:db.Password;$t=$script:db.Tns;$log=$script:db.Log

    $copyWork = {
        param($fm,$sm,$items,$d,$mode,$verify,$writeManifest,$run,$prof,$u,$p,$t,$log,$cancel)
        . $fm;. $sm
        $report={param($done,$total,$message)Write-Progress -Activity 'Delivery' -Status $message -PercentComplete ([int](($done/[Math]::Max($total,1))*100))}
        $stop={Test-Path -LiteralPath $cancel}
        $result=Copy-DeliveryFiles -Items $items -Destination $d -DuplicateMode $mode -VerifyHash $verify -WriteManifest $writeManifest -ReportProgress $report -IsCancelled $stop
        if($run -and -not $result.Cancelled){
            $result|Add-Member NoteProperty RunScriptPath (New-DeliveryRunScript -Items $items -Destination $d -DbUser $u -DbPass $p -TnsName $t -LogFile $log -Profile $prof)
        }
        $result
    }
    $script:copyWorker=[PowerShell]::Create()
    [void]$script:copyWorker.AddScript($copyWork.ToString())
    foreach($argument in @((Join-Path $script:appRoot 'Core.FileOps.ps1'),(Join-Path $script:appRoot 'Core.SqlPlus.ps1'),$jobItems,$dest,$mode,$verify,$writeManifest,$run,$prof,$u,$p,$t,$log,$script:cancelFile)){[void]$script:copyWorker.AddArgument($argument)}
    $script:copyJob=[pscustomobject]@{State='Running'}
    try {$script:copyAsync=$script:copyWorker.BeginInvoke()} catch {
        $script:copyWorker.Dispose();$script:copyWorker=$null;$script:copyJob.State='Failed'
        $DeliveryOptions.IsEnabled=$true;$DestinationMode.IsEnabled=$true;$DestinationPath.IsEnabled=$true;$ChooseDestinationButton.IsEnabled=$true;$BackToReviewButton.IsEnabled=$true
        $CancelDeliveryButton.IsEnabled=$false;$CancelDeliveryButton.Visibility='Collapsed';$DeliveryProgress.Visibility='Collapsed';$DeliveryStatus.Visibility='Collapsed';Update-DestinationState
        [void][Windows.MessageBox]::Show($window,$_.Exception.Message,(Get-LocalizedText 'Could not start delivery'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
        return
    }

    $script:copyTimer=New-Object Windows.Threading.DispatcherTimer
    $script:copyTimer.Interval=[TimeSpan]::FromMilliseconds(200)
    $script:copyTimer.Add_Tick({
      try {
        $p=@($script:copyWorker.Streams.Progress|Select-Object -Last 1)
        if($p.Count){
            $DeliveryProgress.Value=[Math]::Round(($p[0].PercentComplete/100)*$DeliveryProgress.Maximum)
            $DeliveryStatus.Text=Get-LocalizedText $p[0].StatusDescription
            Set-Status (Get-LocalizedText ("Delivering {0}/{1} files" -f [int]$DeliveryProgress.Value,[int]$DeliveryProgress.Maximum))
        }
        if(-not $script:copyAsync.IsCompleted){return}
        $script:copyTimer.Stop()
        $copyError=$null;$result=$null
        try {
            $result=@($script:copyWorker.EndInvoke($script:copyAsync) | Select-Object -Last 1)[0]
            if($script:copyWorker.HadErrors){throw $script:copyWorker.Streams.Error[0]}
            if(-not $result){throw 'Delivery returned no result.'}
            $script:copyJob.State='Completed'
        } catch {$script:copyJob.State='Failed';$copyError=$_.Exception.Message}
        finally {$script:copyWorker.Dispose();$script:copyWorker=$null}
        $DeliveryOptions.IsEnabled=$true;$DestinationMode.IsEnabled=$true;$DestinationPath.IsEnabled=$true;$ChooseDestinationButton.IsEnabled=$true;$BackToReviewButton.IsEnabled=$true;$CancelDeliveryButton.IsEnabled=$false;$CancelDeliveryButton.Visibility='Collapsed';$DeliveryProgress.Visibility='Collapsed';$DeliveryStatus.Visibility='Collapsed';Update-DestinationState
        if(Test-Path $script:cancelFile){Remove-Item $script:cancelFile -Force}
        if($copyError){
            $DeliveryStatus.Visibility='Visible';$DeliveryStatus.Text=Get-LocalizedText 'Delivery failed.';Set-Status 'Delivery failed.' '#B42318'
            [void][Windows.MessageBox]::Show($window,$copyError,(Get-LocalizedText 'Delivery failed'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
            return
        }

        $map=@{}
        foreach($x in $result.Items){$map[$x.Source]=$x}
        foreach($item in $script:items){
            if($map.ContainsKey($item.Source)){
                $item.ActualDestination=$map[$item.Source].ActualDestination
                $item.DeliveryDetail=[string]$map[$item.Source].Status
                $item.DeliveryResult=if($item.DeliveryDetail -match '^Copied and verified'){'Verified'}elseif($item.DeliveryDetail -match '^Copied'){'Copied'}elseif($item.DeliveryDetail -match '^Skipped'){'Skipped'}elseif($item.DeliveryDetail -match '^Cancelled'){'Cancelled'}else{'Failed'}
                $resultMark=if($item.DeliveryResult -in @('Verified','Copied')){[char]0x2713}elseif($item.DeliveryResult -eq 'Failed'){[char]0x2715}else{[char]0x26A0}
                $item.DeliveryResultLabel="$resultMark $($item.DeliveryResult)"
                $item.StatusBrush=$map[$item.Source].StatusBrush
            }
        }
        foreach($column in $FileGrid.Columns){if($column.SortMemberPath -eq 'DeliveryResult'){$column.Visibility='Visible'}}
        Update-Ui
        $copied=$result.CopiedCount
        $skipped=$result.SkippedCount
        $failed=$result.FailedCount
        $deliveryResultTitle=if($failed){'Delivery completed with errors'}elseif($result.Cancelled){'Delivery cancelled'}else{"Delivered $(Format-FileCount $copied) to $($script:deliveryPath)"}
        $ResultTitle.Text=Get-LocalizedText $deliveryResultTitle
        $resultColor=if($failed){'#B42318'}elseif($result.Cancelled){'#A96500'}else{'#16794A'}
        $ResultTitle.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($resultColor)
        $extraMsg=if($result.PSObject.Properties['RunScriptPath'] -and $result.RunScriptPath){if($script:currentProfile -eq 'BVSC'){" (BVSC scripts generated)"}else{" (runscript.txt generated with local repository paths)"}}else{''}
        $ResultSummary.Text=(Get-LocalizedText ("{0} copied {3} {1} skipped {3} {2} failed" -f $copied,$skipped,$failed,[char]0x00B7)) + $(if($extraMsg){[Environment]::NewLine+(Get-LocalizedText $extraMsg)}else{''})
        $script:manifestPath=if($result.PSObject.Properties['RunScriptPath']){$result.RunScriptPath}else{$null}
        $resultBackground=if($failed){'ThemeColor_FFF7F6'}elseif($result.Cancelled){'ThemeColor_WarningBackground'}else{'ResultBackground'}
        $ResultPanel.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,$resultBackground)
        $ResultPanel.Visibility='Visible'
        $ResultPanel.BringIntoView()
        $OpenDestinationButton.IsEnabled=$true
        $script:deliveryCompleted=$true
        $script:lastDeliveredSelection=(@(Get-SelectedItems | ForEach-Object {$_.Source}) -join "`n")
        $StartDeliveryButton.Content=Get-LocalizedText 'Deliver again'
        $StartDeliveryButton.Style=$window.Resources['Secondary']
        $OpenDestinationButton.Style=$window.Resources['Primary']
        $StartDeliveryButton.IsDefault=$false
        $OpenDestinationButton.IsDefault=($script:currentStep -eq 3)
        $OpenManifestButton.Content=Get-LocalizedText 'Open deployment script'
        $OpenManifestButton.IsEnabled=[bool]$script:manifestPath
        $OpenManifestButton.Visibility=if($script:manifestPath){'Visible'}else{'Collapsed'}
        $ReviewErrorsButton.Visibility=if($failed){'Visible'}else{'Collapsed'}
        $ViewRunLogButton.Visibility='Collapsed';$RunAllPanel.Visibility='Collapsed'
        Set-Status $ResultTitle.Text $resultColor

        if($script:runAllAfterDelivery -and -not $result.Cancelled -and -not $failed -and
           $result.PSObject.Properties['RunScriptPath'] -and $result.RunScriptPath){
             try {
                 Invoke-RunAll -RunScriptPath $result.RunScriptPath -Profile $script:currentProfile -Dest $script:deliveryPath
                 Set-Status (Get-LocalizedText 'Running SQL scripts...') '#4B5768'
             } catch {
                 Set-Status (Get-LocalizedText ('Could not start Run All: '+$_.Exception.Message)) '#B42318'
                 [void][Windows.MessageBox]::Show($window,$_.Exception.Message,(Get-LocalizedText 'Could not start Run All'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
             }
        }
      } catch {
        $script:copyTimer.Stop()
        throw "Delivery UI update failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
      }
    })
    $script:copyTimer.Start()
}

$ProjectProfileCombo.Add_SelectionChanged({
    $p = if ($ProjectProfileCombo.SelectedIndex -eq 0) { 'BVSC' } else { 'BSC' }
    if ($p -ne $script:currentProfile) {
        Set-DeliveryProfile $p
        Set-Status "Switched to $p profile" '#16794A'
    }
})

$AddPathsButton.Add_Click({Add-PastedPaths})

$ChooseRepoButton.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $d=New-Object Windows.Forms.FolderBrowserDialog
    if($d.ShowDialog() -eq 'OK'){
        $RepoPath.Text=$d.SelectedPath
        $GitHint.Text=Get-LocalizedText 'Load branches to choose a base and compare branch.'
    }
})

$LoadBranchesButton.Add_Click({
    if($script:backgroundOperation){return}
    $script:allBranches=@();$BaseBranch.ItemsSource=$null;$CompareBranch.ItemsSource=$null
    Set-GitControlsBusy $true
    $GitHint.Text=Get-LocalizedText 'Loading branches and refreshing remotes...'
    try {
        $work={param($module,$path)
            $ErrorActionPreference='Stop';. $module
            $repo=Get-DeliveryGitRoot $path
            $branches=@(Get-DeliveryGitBranches $repo | Sort-Object -Unique)
            $currentResult=Invoke-DeliveryGitRaw $repo @('branch','--show-current')
            if($currentResult.ExitCode -ne 0){throw $currentResult.StdErr}
            $current=if($currentResult.Output.Count){$currentResult.Output[0]}else{''}
            $status=Invoke-DeliveryGitRaw $repo @('status','--porcelain=v1','--untracked-files=no')
            if($status.ExitCode -ne 0){throw $status.StdErr}
            [pscustomobject]@{Repository=$repo;Branches=$branches;Current=$current;ChangeCount=@($status.Output).Count}
        }
        $success={param($context,$result)
            $data=$result[-1];$repo=$data.Repository;$branches=@($data.Branches);$current=$data.Current
            $RepoPath.Text=$repo;Set-GitWorkspaceInfo $(if($current){$current}else{'detached HEAD'}) $data.ChangeCount
            $script:allBranches=$branches;$BaseBranch.ItemsSource=$branches;$CompareBranch.ItemsSource=$branches
            $base=if($branches -contains 'main'){'main'}elseif($branches -contains 'master'){'master'}else{$current}
            $BaseBranch.SelectedItem=$base;$CompareBranch.SelectedItem=$current;$BaseBranch.Text=$base;$CompareBranch.Text=$current
            Enable-BranchTypingSearch -Combo $BaseBranch;Enable-BranchTypingSearch -Combo $CompareBranch
            $GitHint.Text=Get-LocalizedText ("Loaded {0} branches. Ready to compare." -f $branches.Count)
        }
        $failure={param($context,$errorRecord)
            $message=$errorRecord.Exception.Message.Replace([Environment]::NewLine,' ')
            $GitHint.Text=Get-LocalizedText ("Could not load branches: {0}" -f $message)
            [void][Windows.MessageBox]::Show($window,$message,(Get-LocalizedText 'Could not load branches'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
        }
        $finally={param($context)if(-not $script:backgroundOperation){Set-GitControlsBusy $false}}
        Start-DeliveryBackground 'Load branches' $work @((Join-Path $script:appRoot 'Core.Git.ps1'),$RepoPath.Text.Trim()) $null $success $failure $finally
    } catch {
        Set-GitControlsBusy $false
        $GitHint.Text=Get-LocalizedText ("Could not load branches: {0}" -f $_.Exception.Message.Replace([Environment]::NewLine,' '))
    }
})

function Start-GitComparisonWorker($Context) {
    $GitHint.Text=Get-LocalizedText 'Updating both branches and collecting changed files...'
    $work={param($module,$repo,$base,$compare)
        $ErrorActionPreference='Stop';. $module
        $snapshot=New-DeliveryGitSnapshot -Repository $repo -BaseBranch $base -CompareBranch $compare
        $files=@($snapshot.Changes.Keys|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|ForEach-Object {Get-Item -LiteralPath $_})
        [pscustomobject]@{Snapshot=$snapshot;Files=$files}
    }
    $success={param($context,$result)
        $data=$result[-1];$c=$data.Snapshot;$files=@($data.Files)
        $r=Add-Items -Files $files -GitStatus $c.Changes -SourceRoot $c.Root -GitMetadata $c.DiffMetadata
        $sqlCount=@($files|Where-Object {[IO.Path]::GetExtension($_.FullName).Equals('.sql',[StringComparison]::OrdinalIgnoreCase)}).Count
        Sort-ReviewItemsFlexDb
        Set-Status ("Added $(Format-FileCount $r.Added) from Git") '#16794A'
        $GitHint.Text=Get-LocalizedText ("{0} files {2} {1} SQL" -f $r.Added,$sqlCount,[char]0x00B7)
        if($r.Added){Set-Step 2}
    }
    $failure={param($context,$errorRecord)
        $message=$errorRecord.Exception.Message
        $GitHint.Text=Get-LocalizedText ("Could not compare changes: {0}" -f $message.Replace([Environment]::NewLine,' '))
        Set-Status 'Git comparison failed' '#B42318'
        [void][Windows.MessageBox]::Show($window,$message,(Get-LocalizedText 'Git comparison failed'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    }
    $finally={param($context)if(-not $script:backgroundOperation){Set-GitControlsBusy $false}}
    Start-DeliveryBackground 'Compare branches' $work @((Join-Path $script:appRoot 'Core.Git.ps1'),$Context.Repository,$Context.Base,$Context.Compare) $Context $success $failure $finally
}

$AddGitChangesButton.Add_Click({
    if($script:backgroundOperation){return}
    $base=$BaseBranch.Text.Trim();$compare=$CompareBranch.Text.Trim()
    if(-not $base -or -not $compare){[void][Windows.MessageBox]::Show($window,(Get-LocalizedText 'Choose both branches first.'),(Get-LocalizedText 'Git comparison'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Warning);return}
    if($script:items.Count){[void][Windows.MessageBox]::Show($window,(Get-LocalizedText 'Clear the current file list before starting a new Git comparison.'),(Get-LocalizedText 'Git comparison'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Warning);return}
    $context=[pscustomobject]@{Path=$RepoPath.Text.Trim();Base=$base;Compare=$compare;Repository=$null}
    Set-GitControlsBusy $true;$GitHint.Text=Get-LocalizedText 'Checking the current Git workspace...';Set-Status 'Checking Git workspace...'
    $work={param($module,$path)
        $ErrorActionPreference='Stop';. $module
        $repo=Get-DeliveryGitRoot $path
        $branch=Invoke-DeliveryGitRaw $repo @('symbolic-ref','--quiet','--short','HEAD')
        if($branch.ExitCode -ne 0 -or -not $branch.Output.Count){throw 'Checkout a local branch before comparing.'}
        $state=Invoke-DeliveryGitRaw $repo @('status','--porcelain=v1','--untracked-files=no')
        if($state.ExitCode -ne 0){throw "Cannot inspect Git workspace: $($state.StdErr)"}
        [pscustomobject]@{Repository=$repo;Current=$branch.Output[0];Changes=$state.StdOut.TrimEnd();ChangeCount=@($state.Output).Count}
    }
    $success={param($context,$result)
        $data=$result[-1];$context.Repository=$data.Repository
        $RepoPath.Text=$data.Repository;Set-GitWorkspaceInfo $data.Current $data.ChangeCount
        if($data.ChangeCount){throw ("Local workspace has modified tracked files or conflicts. Commit, stash or resolve them before comparing.`n`n"+$data.Changes)}
        if(-not $script:gitCheckoutConfirmed){
            $message="Current branch: $($data.Current)`n`nThe app will check out and pull both branches:`n$($context.Base)`n$($context.Compare)`n`nIt will then restore $($data.Current). Continue?"
            if([Windows.MessageBox]::Show($window,$message,(Get-LocalizedText 'Confirm Git update'),[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){$GitHint.Text=Get-LocalizedText 'Git comparison cancelled.';return}
            $script:gitCheckoutConfirmed=$true
        }
        Start-GitComparisonWorker $context
    }
    $failure={param($context,$errorRecord)
        $message=$errorRecord.Exception.Message
        $GitHint.Text=Get-LocalizedText ("Could not compare changes: {0}" -f $message.Replace([Environment]::NewLine,' '));Set-Status 'Git comparison failed' '#B42318'
        [void][Windows.MessageBox]::Show($window,$message,(Get-LocalizedText 'Git comparison failed'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    }
    $finally={param($context)if(-not $script:backgroundOperation){Set-GitControlsBusy $false}}
    try {Start-DeliveryBackground 'Check Git workspace' $work @((Join-Path $script:appRoot 'Core.Git.ps1'),$context.Path) $context $success $failure $finally}
    catch {Set-GitControlsBusy $false;$GitHint.Text=$_.Exception.Message;[void][Windows.MessageBox]::Show($window,$_.Exception.Message,(Get-LocalizedText 'Git comparison failed'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)}
})

$script:searchTimer.Add_Tick({$script:searchTimer.Stop();Refresh-Grid})
$RepoPath.Add_TextChanged({$GitWorkspaceInfo.Text='';$GitHint.Text='';$GitDirtyWarning.Visibility='Collapsed'})
$SearchBox.Add_TextChanged({$ClearSearchButton.Visibility=if($SearchBox.Text.Length){'Visible'}else{'Collapsed'};$script:searchTimer.Stop();$script:searchTimer.Start()})
$ClearSearchButton.Visibility=if($SearchBox.Text.Length){'Visible'}else{'Collapsed'}
$script:destinationTimer.Add_Tick({$script:destinationTimer.Stop();Update-DestinationState})
$DestinationPath.Add_TextChanged({if($script:deliveryCompleted){Reset-DeliveryPresentation};$StartDeliveryButton.IsEnabled=$false;$DeliveryReadyHint.Text=Get-LocalizedText 'Checking destination...';$script:destinationTimer.Stop();$script:destinationTimer.Start()})
$DuplicateMode.Add_SelectionChanged({Update-DestinationState})
$filterButtons=@($FilterAllButton,$FilterIncludedButton,$FilterExcludedButton,$FilterSqlButton,$FilterErrorsButton)
for($i=0;$i -lt $filterButtons.Count;$i++){$filterButtons[$i].Tag=$i;$filterButtons[$i].Add_Click({param($sender,$eventArgs)$FilterBox.SelectedIndex=[int]$sender.Tag})}
function Update-FilterButtons {
    foreach($button in $filterButtons){
        $active=([int]$button.Tag -eq $FilterBox.SelectedIndex)
        $button.Background=if($active){$window.Resources['ThemeColor_EAF2FF']}else{[Windows.Media.Brushes]::Transparent}
        $button.Foreground=if($active){$window.Resources['ThemeColor_1463D6']}else{$window.Resources['ThemeColor_28384D']}
        $button.FontWeight=if($active){[Windows.FontWeights]::SemiBold}else{[Windows.FontWeights]::Normal}
    }
}
$FilterBox.Add_SelectionChanged({Update-FilterButtons;Refresh-Grid})
$ClearSearchButton.Add_Click({$SearchBox.Clear();[void]$SearchBox.Focus()})
$EmptySelectButton.Add_Click({Set-Step 1})
function Invoke-DeliveryShortcut([string]$Key) {
    switch($Key){
        'F' { if($BackToReviewButton.IsEnabled -and $Step2Button.IsEnabled){Set-Step 2;[void]$SearchBox.Focus();return $true} }
        'D1' { if($BackToReviewButton.IsEnabled){Set-Step 1;return $true} }
        'D2' { if($BackToReviewButton.IsEnabled -and $Step2Button.IsEnabled){Set-Step 2;return $true} }
        'D3' { if($BackToReviewButton.IsEnabled -and $Step3Button.IsEnabled){Set-Step 3;return $true} }
    }
    return $false
}
$window.Add_PreviewKeyDown({param($sender,$eventArgs)
    if(([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0){$eventArgs.Handled=Invoke-DeliveryShortcut ([string]$eventArgs.Key)}
})
$FileGrid.Add_CellEditEnding({$window.Dispatcher.BeginInvoke([Action]{Update-Ui $false},[Windows.Threading.DispatcherPriority]::Background)|Out-Null})
$FileGrid.Add_SelectionChanged({$item=$FileGrid.SelectedItem;$ViewChangesButton.IsEnabled=[bool](-not $script:backgroundOperation -and $item -and $item.PSObject.Properties['GitDiff'] -and $item.GitDiff)})
$ViewChangesButton.Add_Click({Open-DeliveryGitDiff $FileGrid.SelectedItem})
$FileGrid.Add_MouseDoubleClick({param($sender,$eventArgs)
    $node=$eventArgs.OriginalSource;$row=$null
    while($node){
        if($node -is [Windows.Controls.CheckBox]){return}
        if($node -is [Windows.Controls.DataGridRow]){$row=$node;break}
        if($node -is [Windows.FrameworkContentElement]){$node=$node.Parent}
        elseif($node -is [Windows.Media.Visual] -or $node -is [Windows.Media.Media3D.Visual3D]){$node=[Windows.Media.VisualTreeHelper]::GetParent($node)}
        else{break}
    }
    if($row){Open-DeliveryGitDiff $row.Item}
})
$FileGrid.Add_PreviewMouseLeftButtonUp({param($sender,$eventArgs)
    $node=$eventArgs.OriginalSource
    while($node){
        if($node -is [Windows.Controls.CheckBox]){$window.Dispatcher.BeginInvoke([Action]{Update-Ui $false},[Windows.Threading.DispatcherPriority]::Background)|Out-Null;break}
        if($node -is [Windows.Controls.DataGridRow] -or $node -is [Windows.Controls.Primitives.DataGridColumnHeader]){break}
        if($node -is [Windows.FrameworkContentElement]){$node=$node.Parent}
        elseif($node -is [Windows.Media.Visual] -or $node -is [Windows.Media.Media3D.Visual3D]){$node=[Windows.Media.VisualTreeHelper]::GetParent($node)}
        else{break}
    }
})
$FileGrid.Add_PreviewKeyUp({param($sender,$eventArgs)
    if($eventArgs.Key -eq [Windows.Input.Key]::Space -and [Windows.Input.Keyboard]::FocusedElement -is [Windows.Controls.CheckBox]){
        $window.Dispatcher.BeginInvoke([Action]{Update-Ui $false},[Windows.Threading.DispatcherPriority]::Background)|Out-Null
    }
})
$ToggleFilteredButton.Add_Click({
    $targets=@($script:viewItems)
    if($targets.Count -gt 100 -and [Windows.MessageBox]::Show("Change selection for $($targets.Count) filtered files?",'Confirm',[Windows.MessageBoxButton]::YesNo) -ne 'Yes'){return}
    $check=@($targets|Where-Object {-not $_.Included}).Count -gt 0
    foreach($i in $targets){$i.Included=$check}
    Update-Ui
})
$SelectAllButton.Add_Click({foreach($i in $script:items){$i.Included=$true};Update-Ui})
$ClearSelectionButton.Add_Click({foreach($i in $script:items){$i.Included=$false};Update-Ui})
$SortAscendingButton.Add_Click({Sort-ReviewItems $false})
$SortDescendingButton.Add_Click({Sort-ReviewItems $true})
$SortSqlFlexButton.Add_Click({Sort-ReviewItemsFlexDb})
$RemoveSelectedButton.Add_Click({
    $targets=@($script:items|Where-Object Included)
    if(-not $targets.Count){return}
    if([Windows.MessageBox]::Show("Remove $($targets.Count) files from the list? Original files are not deleted.",'Confirm removal',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){return}
    foreach($i in $targets){$script:knownSources.Remove($i.Source)|Out-Null;$script:items.Remove($i)}
    Update-Ui
})
$Step1Button.Add_Click({Set-Step 1})
$Step2Button.Add_Click({if($Step2Button.IsEnabled){Set-Step 2}})
$Step3Button.Add_Click({if($Step3Button.IsEnabled){Set-Step 3}})
$ContinueButton.Add_Click({if($Step3Button.IsEnabled){Set-Step 3}})
$BackToReviewButton.Add_Click({Set-Step 2})
$ChooseDestinationButton.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $d=New-Object Windows.Forms.FolderBrowserDialog
    if($d.ShowDialog() -eq 'OK'){
        $DestinationPath.Text=$d.SelectedPath
        $DestinationError.Visibility='Collapsed'
        Update-DestinationState
    }
})
$DestinationPath.Add_LostKeyboardFocus({Update-DestinationState})
$BranchDestination.Add_Checked({if($script:deliveryCompleted){Reset-DeliveryPresentation};Update-DestinationState})
$ExistingDestination.Add_Checked({if($script:deliveryCompleted){Reset-DeliveryPresentation};Update-DestinationState})
$CompareBranch.Add_SelectionChanged({$step=Get-Variable -Name currentStep -Scope Script -ErrorAction SilentlyContinue;if($step -and $step.Value -eq 3){Update-DestinationState}})
$CompareBranch.Add_LostKeyboardFocus({$step=Get-Variable -Name currentStep -Scope Script -ErrorAction SilentlyContinue;if($step -and $step.Value -eq 3){Update-DestinationState}})
Enable-BranchTypingSearch -Combo $BaseBranch
Enable-BranchTypingSearch -Combo $CompareBranch
$ConfigureSqlButton.Add_Click({Show-SqlDialog})
$CreateRunScript.Add_Checked({$SqlSettingsLine.Visibility='Visible';$SqlPathWarning.Visibility='Visible'})
$CreateRunScript.Add_Unchecked({$SqlSettingsLine.Visibility='Collapsed';$SqlPathWarning.Visibility='Collapsed'})
$StartDeliveryButton.Add_Click({Start-Delivery})
$CancelDeliveryButton.Add_Click({
    if($script:copyJob){
        New-Item -ItemType File -Path $script:cancelFile -Force|Out-Null
        $CancelDeliveryButton.IsEnabled=$false
        $DeliveryStatus.Text=Get-LocalizedText 'Cancelling after the current file...'
    }
})
$OpenDestinationButton.Add_Click({$path=if($script:deliveryPath){$script:deliveryPath}else{$DestinationPath.Text};if(Test-Path $path){Start-Process explorer.exe -ArgumentList ('"'+$path+'"')}})
$OpenManifestButton.Add_Click({if(Test-Path $script:manifestPath){Start-Process $script:manifestPath}})
$ViewRunLogButton.Add_Click({
    try {
        $path=if($script:runAllLogPath){$script:runAllLogPath}elseif((Get-Item -LiteralPath $script:runAllErrorPath).Length){$script:runAllErrorPath}else{$script:runAllOutputPath}
        if(-not [IO.Path]::IsPathRooted($path)){
            $base=if($script:currentProfile -eq 'BVSC'){Join-Path $script:deliveryPath '2.HOST\upgrade\sql'}else{$script:deliveryPath}
            $path=Join-Path $base $path
        }
        if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Log file is not available yet: $path"}
        $dlg=New-Object Windows.Window
        $dlg.Title=Get-LocalizedText 'Run log';$dlg.Width=850;$dlg.Height=600;$dlg.MinWidth=500;$dlg.MinHeight=300;$dlg.Owner=$window;$dlg.WindowStartupLocation='CenterOwner'
        $grid=New-Object Windows.Controls.DockPanel;$grid.Margin=New-Object Windows.Thickness(14);$dlg.Content=$grid
        $label=New-Object Windows.Controls.TextBlock;$label.Text=$path;$label.TextWrapping='Wrap';$label.Margin=New-Object Windows.Thickness(0,0,0,10)
        [Windows.Controls.DockPanel]::SetDock($label,'Top');[void]$grid.Children.Add($label)
        $buttons=New-Object Windows.Controls.StackPanel;$buttons.Orientation='Horizontal';$buttons.HorizontalAlignment='Right';$buttons.Margin=New-Object Windows.Thickness(0,10,0,0)
        [Windows.Controls.DockPanel]::SetDock($buttons,'Bottom');[void]$grid.Children.Add($buttons)
        $reload=New-Object Windows.Controls.Button;$reload.Content=Get-LocalizedText 'Refresh';$reload.MinWidth=90;$reload.Height=32;$reload.Margin=New-Object Windows.Thickness(0,0,8,0);[void]$buttons.Children.Add($reload)
        $close=New-Object Windows.Controls.Button;$close.Content=Get-LocalizedText 'Close';$close.MinWidth=90;$close.Height=32;[void]$buttons.Children.Add($close)
        $logText=New-Object Windows.Controls.TextBox;$logText.IsReadOnly=$true;$logText.AcceptsReturn=$true;$logText.FontFamily='Consolas';$logText.VerticalScrollBarVisibility='Auto';$logText.HorizontalScrollBarVisibility='Auto';[void]$grid.Children.Add($logText)
        $refresh={
            try {
                $stream=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
                try {$reader=New-Object IO.StreamReader($stream,$true);try {$logText.Text=$reader.ReadToEnd()}finally{$reader.Dispose()}}finally{$stream.Dispose()}
            } catch {[void][Windows.MessageBox]::Show($dlg,('Could not read log: '+$_.Exception.Message),'Run log')}
        }
        $reload.Add_Click($refresh);$close.Add_Click({$dlg.Close()});& $refresh;[void]$dlg.ShowDialog()
    } catch {[void][Windows.MessageBox]::Show($window,('Could not open log: '+$_.Exception.Message),'Run log')}
})
$GenerateMd5Button.Add_Click({
    if($script:backgroundOperation){[void][Windows.MessageBox]::Show($window,'Please wait for the current operation to finish.','Generate ZIP MD5');return}
    $folder=$script:deliveryPath
    if(-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)){[void][Windows.MessageBox]::Show($window,'The delivery folder is not available.','Generate ZIP MD5');return}
    try {
        $zips=@(Get-ChildItem -LiteralPath $folder -Filter '*.zip' -File -ErrorAction Stop)
        if($zips.Count -eq 1){$zip=$zips[0].FullName}else{
            $dialog=New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title='Select the delivery ZIP';$dialog.InitialDirectory=$folder;$dialog.Filter='ZIP files (*.zip)|*.zip';$dialog.CheckFileExists=$true
            if($dialog.ShowDialog($window) -ne $true){return}
            $zip=$dialog.FileName
        }
        $GenerateMd5Button.IsEnabled=$false
        Set-Status 'Calculating ZIP MD5...' '#4B5768'
        $work={param($path) $ErrorActionPreference='Stop'; $hash=Get-FileHash -LiteralPath $path -Algorithm MD5; [pscustomobject]@{Path=$path;Hash=$hash.Hash.ToLowerInvariant()}}
        $success={param($context,$result)
            $value=$result[0];$clip=([IO.Path]::GetFileName($value.Path)+' : '+$value.Hash)
            [Windows.Clipboard]::SetText($clip)
            [void][Windows.MessageBox]::Show($window,("Copied to clipboard:`n`n"+$clip),'ZIP MD5',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Information)
            Set-Status 'ZIP MD5 copied to clipboard.' '#16794A'
        }
        $failure={param($context,$errorRecord) [void][Windows.MessageBox]::Show($window,('Could not calculate or copy MD5: '+$errorRecord.Exception.Message),'ZIP MD5',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error);Set-Status 'Could not generate ZIP MD5.' '#B42318'}
        $finally={param($context) $GenerateMd5Button.IsEnabled=$true}
        Start-DeliveryBackground -Name 'ZIP MD5' -Work $work -Arguments @($zip) -Context $null -Success $success -Failure $failure -Finally $finally
    } catch {$GenerateMd5Button.IsEnabled=$true;[void][Windows.MessageBox]::Show($window,('Could not generate MD5: '+$_.Exception.Message),'ZIP MD5',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)}
})
$ReviewErrorsButton.Add_Click({$FilterBox.SelectedIndex=4;Set-Step 2})
$window.Add_SourceInitialized({Set-NativeTitleBarTheme})
$LanguageCombo.Add_SelectionChanged({
    if($script:isUpdatingLanguage){return}
    $nextLanguage=@('English','Arabic','Vietnamese')[$LanguageCombo.SelectedIndex]
    if($nextLanguage -eq $script:language){return}
    $previousLanguage=$script:language
    $script:isUpdatingLanguage=$true
    try {
        $directory=Split-Path -Parent $script:languageSettingsPath
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop|Out-Null
        @{Language=$nextLanguage}|ConvertTo-Json|Set-Content -LiteralPath $script:languageSettingsPath -Encoding UTF8 -ErrorAction Stop
        $script:language=$nextLanguage
        Set-WindowLanguage $window
        Set-Theme $script:theme
        Set-DeliveryProfile $script:currentProfile $false
        Update-Ui
        if($script:lastStatusText){Set-Status $script:lastStatusText}
    } catch {
        $failure=$_.Exception.ToString()
        $script:language=$previousLanguage
        try {
            @{Language=$previousLanguage}|ConvertTo-Json|Set-Content -LiteralPath $script:languageSettingsPath -Encoding UTF8 -ErrorAction Stop
        } catch {
            $failure += [Environment]::NewLine + "Could not restore the previous language setting: $($_.Exception.Message)"
        }
        $LanguageCombo.SelectedIndex=if($previousLanguage -eq 'Arabic'){1}elseif($previousLanguage -eq 'Vietnamese'){2}else{0}
        [void][Windows.MessageBox]::Show($failure,(Get-LocalizedText 'Language setting'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    } finally {
        $script:isUpdatingLanguage=$false
    }
})
function Set-ThemePreference([ValidateSet('System','Light','Dark')][string]$Preference) {
    try {
        $directory=Split-Path -Parent $script:themeSettingsPath
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop|Out-Null
        @{Theme=$Preference}|ConvertTo-Json|Set-Content -LiteralPath $script:themeSettingsPath -Encoding UTF8 -ErrorAction Stop
        $script:themePreference=$Preference
        Set-Theme $(if($Preference -eq 'System'){Get-SystemAppTheme}else{$Preference})
        Set-Step $script:currentStep
    } catch {
        [void][Windows.MessageBox]::Show((Get-LocalizedText ("Could not save the appearance preference: {0}" -f $_.Exception.Message)),(Get-LocalizedText 'Appearance setting'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    }
}
$themeMenu=New-Object Windows.Controls.ContextMenu
$themeMenu.Placement='Bottom'
foreach($preference in @('System','Light','Dark')){
    $entry=New-Object Windows.Controls.MenuItem
    $entry.Header=$preference;$entry.Tag=$preference;$entry.IsCheckable=$true
    $entry.Add_Click({param($sender,$eventArgs)Set-ThemePreference ([string]$sender.Tag)})
    [void]$themeMenu.Items.Add($entry)
}
$DarkModeButton.ContextMenu=$themeMenu
$DarkModeButton.Add_Click({foreach($entry in $themeMenu.Items){$entry.Header=Get-LocalizedText ([string]$entry.Tag);$entry.IsChecked=([string]$entry.Tag -eq $script:themePreference)};$themeMenu.PlacementTarget=$DarkModeButton;$themeMenu.IsOpen=$true})
$script:themeWatchTimer=New-Object Windows.Threading.DispatcherTimer
$script:themeWatchTimer.Interval=[TimeSpan]::FromSeconds(2)
$script:themeWatchTimer.Add_Tick({if($script:themePreference -eq 'System'){$systemTheme=Get-SystemAppTheme;if($systemTheme -ne $script:theme){Set-Theme $systemTheme;Set-Step $script:currentStep}}})
$script:themeWatchTimer.Start()
$window.Add_Closed({$script:themeWatchTimer.Stop()})

Set-Theme $script:theme
if ($script:language -eq 'Arabic') { $LanguageCombo.SelectedIndex=1 } elseif ($script:language -eq 'Vietnamese') { $LanguageCombo.SelectedIndex=2 }
Set-DeliveryProfile 'BSC'
Set-WindowLanguage $window
Update-Ui
Update-FilterButtons
Set-Step 1
if(-not $NoShow){
    Show-StartupProfileDialog
    [void]$window.ShowDialog()
}
