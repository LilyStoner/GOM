Set-StrictMode -Version Latest

function Test-DeliveryExcludedPath {
    param([Parameter(Mandatory)][string]$Path,[string]$ExcludeRules)
    $parts = $Path.Replace('/', '\').Split('\')
    foreach ($rule in @($ExcludeRules -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        if ($rule.StartsWith('*.') -and $Path.EndsWith($rule.Substring(1), [StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($parts -contains $rule) { return $true }
    }
    return $false
}

function Get-DeliveryRelativePath {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Path,
        [bool]$PreserveStructure = $true,
        [string]$Profile = 'BVSC'
    )
    if (-not $PreserveStructure -or -not (Test-Path -LiteralPath $Source -PathType Container)) {
        return [IO.Path]::GetFileName($Path)
    }
    $root = [IO.Path]::GetFullPath($Source).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath($Path)
    $rel = if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $full.Substring($root.Length)
    } else {
        [IO.Path]::GetFileName($full)
    }

    $normalized = $rel.Replace('/', '\')

    # Strip repository folder wrappers like flexDB\ if present
    if ($normalized -match '^(?:.*\\)?flexDB\\(?<afterFlex>.*)$') {
        $normalized = $Matches['afterFlex']
    }

    if ($Profile -eq 'BVSC') {
        # BVSC rule: files in 2.HOST map to 2.HOST\upgrade\sql\2.HOST\...
        if ($normalized -match '^(?:.*\\)?2\.HOST\\(?<subHost>.*)$') {
            $sub = $Matches['subHost']
            if ($sub -notmatch '^upgrade\\sql\\') {
                return "2.HOST\upgrade\sql\2.HOST\$sub"
            }
            return "2.HOST\$sub"
        }
        return $normalized
    } else {
        # Standard / BSC rule: preserve repository structure like 1.BDSHOST, 2.HOST, 3.Service
        return $normalized
    }
}

function Get-DeliverySqlPriority {
    param([Parameter(Mandatory)][string]$Path)
    $p = $Path.Replace('\', '/').ToLowerInvariant()
    if ($p -match '1\.bdshost') { return 10 }
    if ($p -match '0\.changescripts') { return 20 }
    if ($p -match '1\.view') { return 30 }
    if ($p -match '2\.trigger') { return 40 }
    if ($p -match '3\.procedure') { return 50 }
    if ($p -match '4\.function') { return 60 }
    if ($p -match '5\.package') { return 70 }
    if ($p -match '7\.parameters') {
        if ($p -match 'allcode') { return 81 }
        if ($p -match 'apprvrqd') { return 82 }
        if ($p -match 'appmodules') { return 83 }
        if ($p -match 'deferror') { return 84 }
        if ($p -match 'filemap') { return 85 }
        if ($p -match 'filemaster') { return 86 }
        if ($p -match 'focore') { return 87 }
        if ($p -match 'master_trans') { return 88 }
        if ($p -match 'rptfields') { return 89 }
        if ($p -match 'rptmaster') { return 90 }
        if ($p -match 'search_searchfld') { return 91 }
        if ($p -match 'sysvar') { return 92 }
        if ($p -match 'tblbackup') { return 93 }
        return 80
    }
    if ($p -match 'version\.sql') { return 98 }
    return 95
}

function New-DeliveryItem {
    param(
        [Parameter(Mandatory)]$File,
        [Parameter(Mandatory)][string]$Source,
        [bool]$PreserveStructure = $true,
        [string]$GitStatus = $null,
        [string]$Profile = 'BVSC'
    )
    $status = if ($GitStatus) { "Git $GitStatus" } else { 'Ready' }
    $rel = Get-DeliveryRelativePath -Source $Source -Path $File.FullName -PreserveStructure $PreserveStructure -Profile $Profile
    [pscustomobject]@{
        Included = $true
        Source = $File.FullName
        SourceRoot = $Source
        PreserveStructure = $PreserveStructure
        Relative = $rel
        ActualDestination = $null
        Size = [long]$File.Length
        SizeDisplay = Format-DeliverySize $File.Length
        Status = $status
        StatusBrush = '#64748B'
    }
}

function Format-DeliverySize {
    param([long]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    if ($Bytes -lt 1GB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    return ('{0:N2} GB' -f ($Bytes / 1GB))
}

function Get-DeliveryFiles {
    param([Parameter(Mandatory)][string[]]$Paths,[string]$ExcludeRules)
    $files = New-Object System.Collections.Generic.List[object]
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { [void]$files.Add((Get-Item -LiteralPath $path)) }
        elseif (Test-Path -LiteralPath $path -PathType Container) {
            foreach ($file in @(Get-ChildItem -LiteralPath $path -File -Recurse -Force -ErrorAction SilentlyContinue)) {
                if (-not (Test-DeliveryExcludedPath $file.FullName $ExcludeRules)) { [void]$files.Add($file) }
            }
        }
    }
    return $files
}

function Get-DeliveryNextName {
    param([Parameter(Mandatory)][string]$Path)
    $directory = Split-Path -LiteralPath $Path
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    $extension = [IO.Path]::GetExtension($Path)
    for ($i = 1; ; $i++) { $candidate = Join-Path $directory "$name ($i)$extension"; if (-not (Test-Path -LiteralPath $candidate)) { return $candidate } }
}

function ConvertTo-DeliveryBranchFolderName {
    param([string]$BranchName)
    if ([string]::IsNullOrWhiteSpace($BranchName)) { return $null }

    # Git branch names may contain '/', while Windows folder names cannot.
    $folderName = $BranchName.Trim() -replace '[\\/:*?"<>|]+', '-'
    $folderName = $folderName.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($folderName)) { return 'delivery' }
    return $folderName
}

function Copy-DeliveryFiles {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Destination,
        [ValidateSet('Skip','Overwrite','Rename automatically')][string]$DuplicateMode = 'Skip',
        [bool]$VerifyHash,
        [bool]$WriteManifest = $false,
        [scriptblock]$ReportProgress,
        [scriptblock]$IsCancelled
    )
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $manifest = New-Object System.Collections.Generic.List[object]
    $manifestPath = $null
    try {
        for ($index = 0; $index -lt $Items.Count; $index++) {
            if (& $IsCancelled) { break }
            $item = $Items[$index]
            $target = Join-Path $Destination $item.Relative
            try {
                New-Item -ItemType Directory -Path (Split-Path -LiteralPath $target) -Force | Out-Null
                if (Test-Path -LiteralPath $target) {
                    if ($DuplicateMode -eq 'Skip') { $item.Status='Skipped';$item.StatusBrush='#B7791F';[void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Skipped';Detail='File exists'}); continue }
                    if ($DuplicateMode -eq 'Rename automatically') { $target=Get-DeliveryNextName $target }
                }
                & $ReportProgress $index $Items.Count ("Copying $([IO.Path]::GetFileName($item.Source))")
                [IO.File]::Copy($item.Source,$target,$true)
                [IO.File]::SetLastWriteTimeUtc($target,[IO.File]::GetLastWriteTimeUtc($item.Source))
                if ($VerifyHash) {
                    if (& $IsCancelled) { throw 'Cancelled by user' }
                    & $ReportProgress $index $Items.Count ("Verifying $([IO.Path]::GetFileName($item.Source))")
                    if ((Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) { throw 'SHA-256 mismatch' }
                }
                $item.ActualDestination=$target.Substring($Destination.TrimEnd('\').Length).TrimStart('\')
                $item.Status=if($VerifyHash){'Copied and verified'}else{'Copied'};$item.StatusBrush='#15803D'
                [void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Copied';Detail=$item.Status})
            } catch {
                if (& $IsCancelled) { $item.Status='Cancelled';$item.StatusBrush='#64748B';[void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Cancelled';Detail='Cancelled by user'});break }
                $item.Status='Error: '+$_.Exception.Message;$item.StatusBrush='#DC2626';[void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Failed';Detail=$_.Exception.Message})
            } finally { & $ReportProgress ($index+1) $Items.Count $item.Status }
        }
    } finally {
        if ($WriteManifest) {
            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $manifestPath = Join-Path $Destination "delivery_manifest_$stamp.csv"
            $manifest | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
        }
    }
    $copiedCount  = @($manifest | Where-Object Result -eq 'Copied').Count
    $skippedCount = @($manifest | Where-Object Result -eq 'Skipped').Count
    $failedCount  = @($manifest | Where-Object { $_.Result -eq 'Failed' }).Count
    return [pscustomobject]@{
        ManifestPath = $manifestPath
        Cancelled    = (& $IsCancelled)
        Items        = $Items
        CopiedCount  = $copiedCount
        SkippedCount = $skippedCount
        FailedCount  = $failedCount
    }
}
