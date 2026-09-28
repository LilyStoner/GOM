$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$files = @('App.ps1','Core.FileOps.ps1','Core.Git.ps1','Core.SqlPlus.ps1','DeliveryCopy.ps1')
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw "$file has a PowerShell parse error: $($errors[0])" }
}

# Loading the app exercises WPF XAML, every named control, and initial UI state.
& (Join-Path $root 'App.ps1') -NoShow

. (Join-Path $root 'Core.FileOps.ps1')
. (Join-Path $root 'Core.Git.ps1')
$temp = Join-Path $env:TEMP ('delivery-copy-smoke-'+[Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $repository = Join-Path $temp 'repo'
    New-Item -ItemType Directory -Path $repository | Out-Null
    & git -C $repository init -q
    & git -C $repository checkout -qb main
    Set-Content -LiteralPath (Join-Path $repository 'a.txt') -Value 'base'
    & git -C $repository add a.txt
    & git -C $repository -c user.name=Smoke -c user.email=smoke@example.invalid commit -qm base
    & git -C $repository checkout -qb feature
    Set-Content -LiteralPath (Join-Path $repository 'a.txt') -Value 'feature'
    & git -C $repository -c user.name=Smoke -c user.email=smoke@example.invalid commit -qam feature
    Set-Content -LiteralPath (Join-Path $repository 'a.txt') -Value 'workspace'
    & git -C $repository add a.txt
    $changes = Get-DeliveryGitChanges -Repository $repository -BaseBranch main -CompareBranch feature -IncludeWorkspace $true
    if ($changes.Changes.Count -ne 1) { throw 'Git changes must merge committed and workspace changes for the same file.' }

    $file = Get-Item -LiteralPath (Join-Path $repository 'a.txt')
    $item = New-DeliveryItem -File $file -Source $repository -PreserveStructure $true
    $output = Join-Path $temp 'delivery'
    $result = Copy-DeliveryFiles -Items @($item) -Destination $output -DuplicateMode Skip -VerifyHash $true -ReportProgress {param($done,$total,$message)} -IsCancelled {$false}
    if ($result.Items[0].Status -ne 'Copied and verified') { throw 'Copy or SHA-256 verification failed.' }
    if (-not (Test-Path -LiteralPath $result.ManifestPath -PathType Leaf)) { throw 'The delivery manifest was not saved.' }
    if (@(Import-Csv -LiteralPath $result.ManifestPath).Count -ne 1) { throw 'The manifest must contain the copied file.' }
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
