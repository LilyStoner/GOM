$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'App.ps1') -NoShow
$temp=Join-Path $env:TEMP ('delivery-worker-test-'+[guid]::NewGuid().ToString('N'))
try {
    $source=Join-Path $temp 'source';$destination=Join-Path $temp 'destination'
    [void](New-Item -ItemType Directory -Path $source,$destination)
    [IO.File]::WriteAllText((Join-Path $source 'sample.txt'),'delivery content')
    $RepoPath.Text=$source
    [void](Add-Items -Files @((Get-Item (Join-Path $source 'sample.txt'))) -SourceRoot $source)
    $ExistingDestination.IsChecked=$true;$DestinationPath.Text=$destination;$CreateRunScript.IsChecked=$false;$VerifyHash.IsChecked=$true
    $process=[Diagnostics.Process]::GetCurrentProcess();$process.Refresh();$before=$process.WorkingSet64
    Start-Delivery
    $process.Refresh();$during=$process.WorkingSet64
    if(-not $script:copyWorker -or $script:copyJob.State -ne 'Running'){throw 'Delivery worker did not start'}
    if($script:copyWorker -isnot [PowerShell]){throw 'Delivery must run in a PowerShell runspace'}
    $frame=New-Object Windows.Threading.DispatcherFrame
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(50)
    $timer.Add_Tick({if($script:copyJob.State -ne 'Running' -or $watch.Elapsed.TotalSeconds -gt 20){$timer.Stop();$frame.Continue=$false}})
    $timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
    if($script:copyJob.State -ne 'Completed'){throw 'Delivery worker did not complete'}
    if([IO.File]::ReadAllText((Join-Path $destination 'sample.txt')) -ne 'delivery content'){throw 'Delivery content is wrong'}
    if(-not $StartDeliveryButton.IsEnabled){throw 'Delivery button was not restored'}
    $script:items.Clear();$script:knownSources.Clear()
    $files=for($i=0;$i -lt 150;$i++){[IO.File]::WriteAllBytes((Join-Path $source ("cancel-$i.txt")),[byte[]]::new(32768));Get-Item (Join-Path $source ("cancel-$i.txt"))}
    [void](Add-Items -Files $files -SourceRoot $source)
    Start-Delivery
    $CancelDeliveryButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $frame=New-Object Windows.Threading.DispatcherFrame;$watch.Restart();$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
    if($script:copyJob.State -ne 'Completed' -or $ResultTitle.Text -notmatch 'cancel'){throw 'Delivery cancellation was not reported'}
    Write-Host 'In-process delivery worker test passed.'
    Write-Host ("Process working set MB (before / during delivery): {0:N1} / {1:N1}" -f ($before/1MB),($during/1MB))
} finally {
    if($script:copyWorker){$script:copyWorker.Stop();$script:copyWorker.Dispose()}
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
