$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'Core.Git.ps1')
. (Join-Path (Split-Path $PSScriptRoot) 'Core.FileOps.ps1')
$temp = Join-Path $env:TEMP ('gom-git-test-' + [guid]::NewGuid().ToString('N'))
$snapshot = $null
New-Item -ItemType Directory $temp | Out-Null
try {
    $remote=Join-Path $temp 'remote.git'; $author=Join-Path $temp 'author'; $work=Join-Path $temp 'work'
    & git init --bare -q $remote
    & git init -q $author
    & git -C $author remote add origin $remote
    & git -C $author config user.email 'test@example.invalid'
    & git -C $author config user.name 'Test'
    & git -C $author checkout -qb main
    [IO.File]::WriteAllText((Join-Path $author 'base.txt'),'base')
    & git -C $author add .
    & git -C $author commit -qm initial
    & git -C $author push -qu origin main
    & git -C $author checkout -qb feature
    [IO.File]::WriteAllText((Join-Path $author 'feature.txt'),'old')
    & git -C $author add .
    & git -C $author commit -qm feature
    & git -C $author push -qu origin feature
    & git clone -q -b main $remote $work
    [IO.File]::WriteAllText((Join-Path $author 'feature.txt'),'latest')
    & git -C $author commit -qam latest
    & git -C $author push -q
    $snapshot=New-DeliveryGitSnapshot $work 'main' 'origin/feature'
    if ((Get-Content -Raw (Join-Path $snapshot.Root 'feature.txt')) -ne 'latest') { throw 'Snapshot is not the latest remote content' }
    if ((& git -C $work branch --show-current) -ne 'main') { throw 'Original branch was not restored' }
    $file=Get-Item (Join-Path $snapshot.Root 'feature.txt')
    $item=New-DeliveryItem $file $snapshot.Root $true $null 'BSC'
    $deliveryRoot=Join-Path $temp 'delivery'
    $dest=Get-DeliveryDestination -Root $deliveryRoot -BranchName 'feature/test' -UseBranchFolder $true
    if ($dest -ne (Join-Path $deliveryRoot 'feature-test\FLEX')) { throw 'Branch destination path is incorrect' }
    if ((Get-DeliveryDestination -Root $dest -BranchName 'feature/test' -UseBranchFolder $false) -ne $dest) { throw 'Existing delivery folder must be used directly' }
    $missingBranchBlocked=$false
    try { Get-DeliveryDestination -Root $deliveryRoot -BranchName '' -UseBranchFolder $true | Out-Null } catch { $missingBranchBlocked=$true }
    if (-not $missingBranchBlocked) { throw 'Branch folder mode must require a branch name' }
    $result=Copy-DeliveryFiles @($item) $dest 'Overwrite' $true $false {param($a,$b,$c)} {$false}
    if ((Get-Content -Raw (Join-Path $dest 'feature.txt')) -ne 'latest') { throw 'Delivery content differs from latest compare branch' }
    [IO.File]::WriteAllText((Join-Path $dest 'feature.txt'),'old delivery')
    [IO.Directory]::CreateDirectory((Join-Path $dest '.svn')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $dest '.svn\keep'),'svn metadata')
    [IO.File]::WriteAllText((Join-Path $dest 'keep.txt'),'existing file')
    $existingDest=Get-DeliveryDestination -Root $dest -BranchName 'ignored' -UseBranchFolder $false
    $repeat=Copy-DeliveryFiles @($item) $existingDest 'Overwrite' $true $false {param($a,$b,$c)} {$false}
    if ($repeat.FailedCount -ne 0 -or (Get-Content -Raw (Join-Path $dest 'feature.txt')) -ne 'latest') { throw 'Repeat delivery did not overwrite the existing file' }
    if ((Get-Content -Raw (Join-Path $dest '.svn\keep')) -ne 'svn metadata' -or (Get-Content -Raw (Join-Path $dest 'keep.txt')) -ne 'existing file') { throw 'Repeat delivery changed unrelated files or SVN metadata' }
    [IO.File]::WriteAllText((Join-Path $work 'untracked.txt'),'uncommitted')
    $second=New-DeliveryGitSnapshot $work 'main' 'feature'
    if ((Get-Content -Raw (Join-Path $work 'untracked.txt')) -ne 'uncommitted') { throw 'Untracked file was changed' }
    Remove-Item -LiteralPath $second.Root -Recurse -Force
    [IO.File]::WriteAllText((Join-Path $work 'base.txt'),'modified')
    $blocked=$false
    try { New-DeliveryGitSnapshot $work 'main' 'feature' | Out-Null } catch { $blocked=$true }
    if (-not $blocked) { throw 'Dirty workspace was not blocked' }
    [IO.File]::WriteAllText((Join-Path $work 'base.txt'),'base')
    $retry=New-DeliveryGitSnapshot $work 'main' 'feature'
    if ((Get-Content -Raw (Join-Path $retry.Root 'feature.txt')) -ne 'latest') { throw 'Retry after cleaning workspace did not use current status' }
    Remove-Item -LiteralPath $retry.Root -Recurse -Force

    # Reproduce retry after a tracked change is committed and pushed, not merely reverted.
    [IO.File]::WriteAllText((Join-Path $work 'base.txt'),'pushed from work')
    $blocked=$false
    try { New-DeliveryGitSnapshot $work 'main' 'feature' | Out-Null } catch { $blocked=$true }
    if (-not $blocked) { throw 'Tracked modification should block comparison before commit' }
    & git -C $work -c user.name=Test -c user.email=test@example.invalid commit -qam 'Update base'
    if ($LASTEXITCODE -ne 0) { throw 'Test commit failed' }
    & git -C $work push -q
    if ($LASTEXITCODE -ne 0) { throw 'Test push failed' }
    $pushedRetry=New-DeliveryGitSnapshot $work 'main' 'feature'
    $basePath=Join-Path $pushedRetry.Root 'base.txt'
    $featurePath=Join-Path $pushedRetry.Root 'feature.txt'
    if ($pushedRetry.Changes.Count -ne 2 -or -not $pushedRetry.Changes.ContainsKey($basePath) -or -not $pushedRetry.Changes.ContainsKey($featurePath)) { throw 'Retry after commit and push returned the wrong changed paths' }
    if ((Get-Content -Raw $basePath) -ne 'base' -or (Get-Content -Raw $featurePath) -ne 'latest') { throw 'Retry snapshot does not contain compare-branch contents' }
    if ((& git -C $work branch --show-current) -ne 'main') { throw 'Retry did not restore the original branch' }
    Remove-Item -LiteralPath $pushedRetry.Root -Recurse -Force
    Write-Host 'Git snapshot tests passed.'
} finally {
    if ($snapshot -and (Test-Path $snapshot.Root)) { Remove-Item -LiteralPath $snapshot.Root -Recurse -Force }
    if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
