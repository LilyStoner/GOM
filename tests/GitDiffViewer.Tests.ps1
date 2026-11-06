$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'Core.Git.ps1')
$temp=Join-Path $env:TEMP ('delivery-diff-test-'+[guid]::NewGuid().ToString('N'))
$snap=$null;$files=@()
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $remote=Join-Path $temp 'remote.git';$author=Join-Path $temp 'author';$work=Join-Path $temp 'work'
    & git init --bare -q $remote
    & git init -q $author
    & git -C $author remote add origin $remote
    & git -C $author config user.email 'test@example.invalid'
    & git -C $author config user.name 'Test'
    & git -C $author checkout -qb main
    [IO.File]::WriteAllText((Join-Path $author 'five changes.sql'),"BASE`n")
    [IO.File]::WriteAllText((Join-Path $author 'old name.sql'),"one`ntwo`nthree`n")
    & git -C $author add .
    & git -C $author commit -qm initial
    & git -C $author push -qu origin main
    & git -C $author checkout -qb feature
    for($i=1;$i -le 5;$i++){
        [IO.File]::AppendAllText((Join-Path $author 'five changes.sql'),"change $i`n")
        & git -C $author add 'five changes.sql'
        & git -C $author commit -qm "change $i"
        if($LASTEXITCODE -ne 0){throw 'Test commit failed'}
    }
    & git -C $author mv 'old name.sql' 'renamed file.sql'
    [IO.File]::WriteAllText((Join-Path $author 'new file.SQL'),"NEW`n")
    & git -C $author add .
    & git -C $author commit -qm 'rename and add'
    & git -C $author push -qu origin feature
    & git clone -q -b main $remote $work
    $before=(& git -C $work status --porcelain) -join "`n"
    $snap=New-DeliveryGitSnapshot $work 'main' 'origin/feature'

    $multiKey=Join-Path $snap.Root 'five changes.sql'
    $meta=$snap.DiffMetadata[$multiKey]
    if(-not $meta -or $meta.BasePath -ne 'five changes.sql' -or $meta.ComparePath -ne 'five changes.sql'){throw 'Modified file metadata is incorrect'}
    [IO.File]::AppendAllText((Join-Path $author 'five changes.sql'),"change 6 after snapshot`n")
    & git -C $author add 'five changes.sql'
    & git -C $author commit -qm 'new commit after snapshot'
    & git -C $author push -q
    if($LASTEXITCODE -ne 0){throw 'Could not advance the test remote'}
    $diff=New-DeliveryGitDiffFiles $meta;$files+=,$diff.Root
    $arguments=@(Get-DeliveryTortoiseArguments $meta $diff)
    if($arguments.Count -ne 5 -or $arguments[0] -ne '/readonly' -or $arguments[1] -ne ('/base:"{0}"' -f $diff.BaseFile) -or $arguments[2] -ne ('/mine:"{0}"' -f $diff.CompareFile)){throw 'TortoiseGitMerge arguments must open both temporary files read-only'}
    if([IO.File]::ReadAllText($diff.BaseFile) -ne "BASE`n"){throw 'Base must be the base-branch tip'}
    if([IO.File]::ReadAllText($diff.CompareFile) -ne "BASE`nchange 1`nchange 2`nchange 3`nchange 4`nchange 5`n"){throw 'Compare side must include all five commits'}

    $renameKey=Join-Path $snap.Root 'renamed file.sql'
    $rename=$snap.DiffMetadata[$renameKey]
    if(-not $rename -or $rename.BasePath -ne 'old name.sql' -or $rename.ComparePath -ne 'renamed file.sql'){throw 'Rename must preserve old and new paths'}
    $renamed=New-DeliveryGitDiffFiles $rename;$files+=,$renamed.Root
    if([IO.File]::ReadAllText($renamed.BaseFile) -ne [IO.File]::ReadAllText($renamed.CompareFile)){throw 'Renamed file content did not match'}

    $newKey=Join-Path $snap.Root 'new file.SQL'
    $newMeta=$snap.DiffMetadata[$newKey]
    if(-not $newMeta -or $newMeta.BasePath){throw 'Added file must have no base path'}
    $added=New-DeliveryGitDiffFiles $newMeta;$files+=,$added.Root
    if((Get-Item $added.BaseFile).Length -ne 0 -or [IO.File]::ReadAllText($added.CompareFile) -ne "NEW`n"){throw 'Added file comparison must have an empty base'}

    # Compare temp files may be edited externally; the snapshot and working tree remain intact.
    [IO.File]::WriteAllText($diff.CompareFile,'changed in viewer')
    if([IO.File]::ReadAllText($multiKey) -notmatch 'change 5'){throw 'Viewer temporary copy must not alter the delivery snapshot'}
    if(((& git -C $work status --porcelain) -join "`n") -ne $before){throw 'Viewing diff must not modify the working tree'}
    if((& git -C $work branch --show-current) -ne 'main'){throw 'Viewing diff must preserve the current branch'}
    Write-Host 'Git diff viewer tests passed.'
} finally {
    foreach($folder in $files){if(Test-Path -LiteralPath $folder){Remove-Item -LiteralPath $folder -Recurse -Force}}
    if($snap -and (Test-Path -LiteralPath $snap.Root)){Remove-Item -LiteralPath $snap.Root -Recurse -Force}
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
