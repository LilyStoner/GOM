$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'Core.Git.ps1')
$temp=Join-Path $env:TEMP ('delivery-batch-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $repo=Join-Path $temp 'repo';$batchDir=Join-Path $temp 'batch';$singleDir=Join-Path $temp 'single'
    New-Item -ItemType Directory -Path $repo,$batchDir,$singleDir | Out-Null
    & git -C $repo init -q
    & git -C $repo config core.autocrlf false
    for($i=0;$i -lt 120;$i++){
        $name=if($i -eq 0){'file '+[char]0x00E9+'.SQL'}else{('file {0:D3}.sql' -f $i)}
        if($i -eq 0){$content=[byte[]]@()}elseif($i -eq 1){$content=New-Object byte[] 131101;for($j=0;$j -lt $content.Length;$j++){$content[$j]=[byte]($j % 256)}}else{$content=[Text.Encoding]::UTF8.GetBytes("line $i`n")}
        [IO.File]::WriteAllBytes((Join-Path $repo $name),$content)
    }
    & git -C $repo add .
    & git -C $repo -c user.name=Test -c user.email=test@example.invalid commit -qm 'batch fixtures'
    if($LASTEXITCODE -ne 0){throw 'Could not commit batch fixtures'}
    $commit=(& git -C $repo rev-parse HEAD).Trim()
    $entries=@(Get-ChildItem -LiteralPath $repo -File | ForEach-Object {[pscustomobject]@{RelativePath=$_.Name;Destination=(Join-Path $batchDir $_.Name)}})
    $timer=[Diagnostics.Stopwatch]::StartNew()
    Export-DeliveryGitBlobs -Repository $repo -Commit $commit -Entries $entries
    $timer.Stop();$batchMs=$timer.ElapsedMilliseconds
    $timer.Restart()
    foreach($entry in $entries){Export-DeliveryGitBlob $repo $commit $entry.RelativePath (Join-Path $singleDir $entry.RelativePath)}
    $timer.Stop();$singleMs=$timer.ElapsedMilliseconds
    foreach($entry in $entries){
        $left=[IO.File]::ReadAllBytes($entry.Destination);$right=[IO.File]::ReadAllBytes((Join-Path $singleDir $entry.RelativePath))
        if(-not [Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($left,$right)){throw "Batch content differed for $($entry.RelativePath)"}
    }
    $missingFailed=$false
    try {Export-DeliveryGitBlobs -Repository $repo -Commit $commit -Entries @([pscustomobject]@{RelativePath='missing.sql';Destination=(Join-Path $batchDir 'missing.sql')})} catch {$missingFailed=$true}
    if(-not $missingFailed){throw 'Missing Git objects must produce an error'}
    Write-Host "Batch Git tests passed: $($entries.Count) files including empty, binary and Unicode paths. Batch $batchMs ms; one-process-per-file $singleMs ms."
} finally {
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
