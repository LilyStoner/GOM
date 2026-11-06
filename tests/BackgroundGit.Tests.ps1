$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'App.ps1') -NoShow
$process=[Diagnostics.Process]::GetCurrentProcess();$process.Refresh()
$baselineWorkingSet=$process.WorkingSet64;$baselinePrivate=$process.PrivateMemorySize64
$temp=Join-Path $env:TEMP ('delivery-background-test-'+[guid]::NewGuid().ToString('N'))
$createdSnapshot=$null
$createdDiff=$null
$script:testBgValue=$null;$script:testBgError=$null
function Wait-TestBackground {
    $timeout=[Diagnostics.Stopwatch]::StartNew()
    while($script:backgroundOperation){
        Complete-DeliveryBackground
        if($timeout.Elapsed.TotalSeconds -gt 30){throw 'Background operation timed out'}
        Start-Sleep -Milliseconds 20
    }
}
try {
    # A deliberately slow worker must return control immediately and complete through the callback.
    $work={param($delay) Start-Sleep -Milliseconds $delay; 'finished'}
    $success={param($context,$result)$script:testBgValue=$result[-1]}
    $failure={param($context,$errorRecord)$script:testBgError=$errorRecord.Exception.Message}
    $finally={param($context)}
    $watch=[Diagnostics.Stopwatch]::StartNew()
    Start-DeliveryBackground 'test' $work @(1200) $null $success $failure $finally
    $watch.Stop()
    if($watch.ElapsedMilliseconds -gt 750){throw "Starting background work blocked for $($watch.ElapsedMilliseconds) ms"}
    if(-not $script:backgroundOperation){throw 'Slow work should still be running after the UI call returns'}
    $script:testUiPulses=0;$script:testPumpWatch=[Diagnostics.Stopwatch]::StartNew()
    $script:testPumpFrame=New-Object Windows.Threading.DispatcherFrame
    $script:testPumpTimer=New-Object Windows.Threading.DispatcherTimer
    $script:testPumpTimer.Interval=[TimeSpan]::FromMilliseconds(30)
    $script:testPumpTimer.Add_Tick({
        $script:testUiPulses++
        if(-not $script:backgroundOperation -or $script:testPumpWatch.Elapsed.TotalSeconds -gt 10){$script:testPumpTimer.Stop();$script:testPumpFrame.Continue=$false}
    })
    $script:testPumpTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($script:testPumpFrame)
    if($script:backgroundOperation){throw 'Dispatcher did not complete background work'}
    if($script:testUiPulses -lt 5){throw 'UI dispatcher did not stay responsive while work was running'}
    if($script:testBgError -or $script:testBgValue -ne 'finished'){throw "Background callback failed: $script:testBgError"}
    Release-IdleBackgroundPool
    if($script:backgroundPool){throw 'Idle runspace pool was not released'}

    $script:testBgError=$null
    Start-DeliveryBackground 'test failure' {throw 'expected test failure'} @() $null $success $failure $finally
    Wait-TestBackground
    if($script:testBgError -notmatch 'expected test failure'){throw 'Background errors were not returned to the UI callback'}

    New-Item -ItemType Directory -Path $temp | Out-Null
    $remote=Join-Path $temp 'remote.git';$author=Join-Path $temp 'author';$repo=Join-Path $temp 'repo'
    & git init --bare -q $remote
    & git init -q $author
    & git -C $author remote add origin $remote
    & git -C $author config user.email 'test@example.invalid'
    & git -C $author config user.name 'Test'
    & git -C $author checkout -qb main
    [IO.File]::WriteAllText((Join-Path $author 'file.sql'),'base')
    & git -C $author add .
    & git -C $author commit -qm base
    & git -C $author push -qu origin main
    & git -C $author checkout -qb feature
    [IO.File]::WriteAllText((Join-Path $author 'file.sql'),'compare version')
    & git -C $author commit -qam feature
    & git -C $author push -qu origin feature
    & git clone -q -b main $remote $repo

    # Exercise the same event handlers as the buttons, with an isolated local remote.
    $RepoPath.Text=$repo
    $watch.Restart();$LoadBranchesButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$watch.Stop()
    $loadStartMs=$watch.ElapsedMilliseconds
    if($watch.ElapsedMilliseconds -gt 750 -or -not $script:backgroundOperation){throw 'Load branches did not return promptly'}
    if($RepoPath.IsEnabled -or $LoadBranchesButton.IsEnabled){throw 'Git controls must be locked while loading'}
    Wait-TestBackground
    if($script:allBranches -notcontains 'origin/feature' -or -not $LoadBranchesButton.IsEnabled){throw 'Branches were not loaded or controls were not restored'}
    $BaseBranch.Text='main';$CompareBranch.Text='origin/feature';$script:gitCheckoutConfirmed=$true
    $watch.Restart();$AddGitChangesButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent));$watch.Stop()
    $compareStartMs=$watch.ElapsedMilliseconds
    if($watch.ElapsedMilliseconds -gt 750 -or -not $script:backgroundOperation){throw 'Git comparison did not return promptly'}
    Wait-TestBackground
    if($script:items.Count -ne 1 -or -not $script:items[0].GitDiff){throw 'Background Git comparison did not return the file and diff metadata'}
    $createdSnapshot=$script:items[0].SourceRoot
    if([IO.File]::ReadAllText($script:items[0].Source) -ne 'compare version'){throw 'Snapshot content must match the compare branch'}
    if((& git -C $repo branch --show-current) -ne 'main'){throw 'Background comparison did not restore the original branch'}
    $gitItem=$script:items[0]
    if($gitItem.ScriptSource -ne (Join-Path $repo 'file.sql')){throw 'Git SQL script path must point to the original repository'}
    $scriptItem=[pscustomobject]@{Source=$gitItem.Source;ScriptSource=$gitItem.ScriptSource;ActualDestination='file.sql';Status='Copied'}
    $scriptDir=Join-Path $temp 'generated scripts'
    [void](New-Item -ItemType Directory -Path $scriptDir)
    $generated=New-DeliveryRunScript -Items @($scriptItem) -Destination $scriptDir -DbUser 'test' -DbPass 'test' -TnsName 'test' -Profile 'Other'
    $text=[IO.File]::ReadAllText($generated)
    if(-not $text.Contains('@'+$gitItem.ScriptSource)){throw 'Generated script must use the repository path rather than the snapshot path'}
    if($text.Contains($gitItem.Source)){throw 'Generated script must not use the temporary snapshot path'}
    $blocked=$false
    try {Invoke-RunAll -RunScriptPath $generated -Profile 'Other' -Dest $scriptDir} catch {$blocked=$_.Exception.Message -match 'differs from the compared version'}
    if(-not $blocked){throw 'Run All must reject a repository file that differs from the pinned snapshot'}
    $spaceSource=Join-Path $temp 'repository with spaces\a file.sql'
    $scriptItem.ScriptSource=$spaceSource
    $generated=New-DeliveryRunScript -Items @($scriptItem) -Destination $scriptDir -DbUser 'test' -DbPass 'test' -TnsName 'test' -Profile 'Other'
    if(-not [IO.File]::ReadAllText($generated).Contains(('@"'+$spaceSource+'"'))){throw 'SQL paths containing spaces must be quoted'}
    $diffStartMs=$null
    if(Find-DeliveryTortoiseGitMerge){
        # Intercept only the launcher so the asynchronous preparation can be tested without opening a viewer window.
        function Start-DeliveryDiffViewer([string]$Tool,[object[]]$Arguments){$script:testDiffArgs=$Arguments}
        $script:testDiffArgs=$null
        $FileGrid.SelectedItem=$script:items[0]
        $watch.Restart();Open-DeliveryGitDiff $script:items[0];$watch.Stop()
        $diffStartMs=$watch.ElapsedMilliseconds
        if($watch.ElapsedMilliseconds -gt 750 -or -not $script:backgroundOperation){throw 'Opening diff did not return promptly'}
        Wait-TestBackground
        if(-not $script:testDiffArgs -or $script:testDiffArgs[0] -ne '/readonly'){throw 'Diff viewer was not launched read-only'}
        $left=[regex]::Match([string]$script:testDiffArgs[1],'^/base:"(.+)"$').Groups[1].Value
        $right=[regex]::Match([string]$script:testDiffArgs[2],'^/mine:"(.+)"$').Groups[1].Value
        if(-not $left -or -not $right){throw 'Diff viewer file arguments were invalid'}
        $createdDiff=[IO.Path]::GetDirectoryName($left)
        if([IO.File]::ReadAllText($left) -ne 'base' -or [IO.File]::ReadAllText($right) -ne 'compare version'){throw 'Background diff must compare the pinned base and compare contents'}
    } else { Write-Host 'TortoiseGitMerge is not installed; skipped the launcher integration check.' }
    $process=[Diagnostics.Process]::GetCurrentProcess();$process.Refresh()
    $activeWorkingSet=$process.WorkingSet64;$activePrivate=$process.PrivateMemorySize64
    Release-IdleBackgroundPool;$process.Refresh()
    Write-Host ("Background Git tests passed. UI return: load {0} ms, compare {1} ms, diff {2} ms." -f $loadStartMs,$compareStartMs,$diffStartMs)
    Write-Host ("Memory MB (working set/private): initial {0:N1}/{1:N1}; after work {2:N1}/{3:N1}; after releasing idle pool {4:N1}/{5:N1}." -f ($baselineWorkingSet/1MB),($baselinePrivate/1MB),($activeWorkingSet/1MB),($activePrivate/1MB),($process.WorkingSet64/1MB),($process.PrivateMemorySize64/1MB))
} finally {
    if($script:backgroundOperation){$script:backgroundOperation.Worker.Stop();$script:backgroundOperation.Worker.Dispose();$script:backgroundOperation=$null}
    if($createdDiff -and (Test-Path -LiteralPath $createdDiff)){Remove-Item -LiteralPath $createdDiff -Recurse -Force}
    if($createdSnapshot -and (Test-Path -LiteralPath $createdSnapshot)){Remove-Item -LiteralPath $createdSnapshot -Recurse -Force}
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
