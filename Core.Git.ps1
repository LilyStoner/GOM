Set-StrictMode -Version Latest

function Invoke-DeliveryGitRaw {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    
    $argParts = New-Object System.Collections.Generic.List[string]
    [void]$argParts.Add('-c')
    [void]$argParts.Add("safe.directory=`"$Repository`"")
    [void]$argParts.Add('-C')
    [void]$argParts.Add("`"$Repository`"")
    foreach ($a in $Arguments) {
        if ($a -match '[\s"]') {
            [void]$argParts.Add('"' + $a.Replace('"', '\"') + '"')
        } else {
            [void]$argParts.Add($a)
        }
    }
    $psi.Arguments = $argParts -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $stderrTask=$proc.StandardError.ReadToEndAsync()
        $stdout = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        $stderr=$stderrTask.GetAwaiter().GetResult()
        $exitCode=$proc.ExitCode
    } finally { $proc.Dispose() }

    $lines = New-Object System.Collections.Generic.List[string]
    if ($stdout) {
        foreach ($line in ($stdout -split "`r?`n")) {
            $t = $line.Trim()
            if ($t) { [void]$lines.Add($t) }
        }
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($lines.ToArray())
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Invoke-DeliveryGit {
    param([Parameter(Mandatory)][string]$Repository,[Parameter(Mandatory)][string[]]$Arguments)
    $res = Invoke-DeliveryGitRaw -Repository $Repository -Arguments $Arguments
    if ($res.ExitCode -ne 0) {
        throw "Git $($Arguments -join ' ') failed: $($res.StdErr)"
    }
    return @($res.Output | Where-Object {
        $_ -notmatch '(?i)^warning:' -and $_ -notmatch '(?i)LF will be replaced by CRLF'
    })
}

function Get-DeliveryGitRoot {
    param([Parameter(Mandatory)][string]$Path)
    $candidate = $Path.Trim()
    while ($candidate -and -not (Test-Path -LiteralPath $candidate -PathType Container)) {
        $parent = Split-Path -LiteralPath $candidate -Parent
        if ($parent -eq $candidate) { break }
        $candidate = $parent
    }
    if (-not $candidate) { throw 'Choose an existing source folder first.' }
    $result = @(Invoke-DeliveryGit $candidate @('rev-parse', '--show-toplevel'))
    return $result[0].Trim().Replace('/', '\')
}

function Sync-DeliveryGitRemote {
    param([Parameter(Mandatory)][string]$Repository)
    $remotesRes = Invoke-DeliveryGitRaw $Repository @('remote')
    if ($remotesRes.ExitCode -eq 0 -and $remotesRes.Output.Count -gt 0 -and $remotesRes.Output[0]) {
        [void](Invoke-DeliveryGit $Repository @('fetch', '--all', '--prune'))
    }
}

function New-DeliveryGitSnapshot {
    param([string]$Repository,[string]$BaseBranch,[string]$CompareBranch)
    $state = Invoke-DeliveryGitRaw $Repository @('status','--porcelain=v1','--untracked-files=no')
    if ($state.ExitCode -ne 0) { throw "Cannot inspect Git workspace: $($state.StdErr)" }
    if ($state.StdOut.Trim()) { throw ("Local workspace has modified tracked files or conflicts. Commit, stash or resolve them before comparing.`n`n" + $state.StdOut.TrimEnd()) }
    $original = @(Invoke-DeliveryGit $Repository @('symbolic-ref','--quiet','--short','HEAD'))
    if (-not $original.Count) { throw 'Checkout a local branch before comparing.' }
    Sync-DeliveryGitRemote $Repository
    $locals = @()
    foreach ($ref in @($BaseBranch,$CompareBranch)) {
        $name = $ref.Trim()
        $verify = Invoke-DeliveryGitRaw $Repository @('show-ref','--verify','--quiet',"refs/heads/$name")
        if ($verify.ExitCode -ne 0) {
            $remote = @(Invoke-DeliveryGit $Repository @('for-each-ref',"refs/remotes/$name",'--format=%(refname:short)'))
            if ($remote.Count -ne 1 -or $remote[0] -ne $name) { throw "Branch '$name' is not a local branch or an exact remote branch." }
            $split = $name.IndexOf('/')
            if ($split -lt 1) { throw "Cannot determine remote for '$name'." }
            $localName = $name.Substring($split + 1)
            $existing = Invoke-DeliveryGitRaw $Repository @('show-ref','--verify','--quiet',"refs/heads/$localName")
            if ($existing.ExitCode -eq 0) {
                $upstream = @(Invoke-DeliveryGit $Repository @('rev-parse','--abbrev-ref',"$localName@{upstream}"))
                if ($upstream[0] -ne $name) { throw "Local branch '$localName' tracks a different remote. Select the correct branch." }
            } else {
                [void](Invoke-DeliveryGit $Repository @('branch','--track',$localName,$name))
            }
            $name = $localName
        }
        $locals += $name
    }
    try {
        foreach ($name in @($locals | Select-Object -Unique)) {
            [void](Invoke-DeliveryGit $Repository @('checkout',$name))
            [void](Invoke-DeliveryGit $Repository @('pull','--ff-only'))
            $localHead = @(Invoke-DeliveryGit $Repository @('rev-parse','HEAD'))[0]
            $remoteHead = @(Invoke-DeliveryGit $Repository @('rev-parse','@{upstream}'))[0]
            if ($localHead -ne $remoteHead) { throw "Branch '$name' differs from its upstream after pull. Resolve local commits before comparing." }
        }
        $baseCommit = @(Invoke-DeliveryGit $Repository @('rev-parse',"$($locals[0])^{commit}"))[0]
        $compareCommit = @(Invoke-DeliveryGit $Repository @('rev-parse',"$($locals[1])^{commit}"))[0]
        $diff = Invoke-DeliveryGitRaw $Repository @('-c','core.quotepath=false','diff','--name-status','-z','-M','--diff-filter=ACMR',"$baseCommit..$compareCommit")
        if ($diff.ExitCode -ne 0) { throw "Git diff failed: $($diff.StdErr)" }
        $tokens = $diff.StdOut -split "`0"
        $snapshot = Join-Path ([IO.Path]::GetTempPath()) ('delivery-snapshot-' + [Guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $snapshot)
        $changes = @{}; $diffMetadata = @{}; $exportEntries=New-Object 'System.Collections.Generic.List[object]'
        for ($i=0; $i -lt $tokens.Count -and $tokens[$i]; $i++) {
            $status = $tokens[$i]; $i++; $relative = $tokens[$i]; $oldRelative=$relative
            if ($status -match '^[RC]') { $i++; $relative = $tokens[$i] }
            $target = Join-Path $snapshot $relative
            [void](New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force)
            [void]$exportEntries.Add([pscustomobject]@{RelativePath=$relative;Destination=$target})
            $fullTarget=[IO.Path]::GetFullPath($target)
            $changes[$fullTarget]=$status
            $diffMetadata[$fullTarget]=[pscustomobject]@{Repository=$Repository;BaseCommit=$baseCommit;CompareCommit=$compareCommit;BaseBranch=$BaseBranch;CompareBranch=$CompareBranch;BasePath=$(if($status -match '^A'){$null}else{$oldRelative});ComparePath=$relative;Status=$status}
        }
        Export-DeliveryGitBlobs -Repository $Repository -Commit $compareCommit -Entries @($exportEntries.ToArray())
        return [pscustomobject]@{Root=$snapshot; Changes=$changes; DiffMetadata=$diffMetadata; Base=$baseCommit; Compare=$compareCommit}
    } finally {
        $restore=Invoke-DeliveryGitRaw $Repository @('checkout',$original[0])
        if ($restore.ExitCode -ne 0) { throw "Failed to restore original branch '$($original[0])': $($restore.StdErr)" }
    }
}

function Export-DeliveryGitBlobs {
    param([string]$Repository,[string]$Commit,[object[]]$Entries)
    if(-not $Entries.Count){return}
    if($Commit -notmatch '^[0-9a-fA-F]{40,64}$'){throw 'Invalid Git commit identifier.'}
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName='git';$psi.UseShellExecute=$false;$psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.CreateNoWindow=$true
    $psi.Arguments='-c safe.directory="'+$Repository+'" -C "'+$Repository+'" cat-file --batch'
    $process=[Diagnostics.Process]::Start($psi)
    try {
        $stderrTask=$process.StandardError.ReadToEndAsync()
        $inputStream=$process.StandardInput.BaseStream;$output=$process.StandardOutput.BaseStream
        $buffer=New-Object byte[] 65536
        # Windows PowerShell 5.1 can emit a UTF-8 preamble when exposing StandardInput.BaseStream.
        # Consume it with a harmless missing-object probe so the first real path is never prefixed.
        $probe=[Text.Encoding]::UTF8.GetBytes("?delivery-batch-probe-invalid-object`n")
        $inputStream.Write($probe,0,$probe.Length);$inputStream.Flush()
        $probeHeader=New-Object Text.StringBuilder
        while($true){$byte=$output.ReadByte();if($byte -lt 0){throw 'Git batch process ended during initialization.'};if($byte -eq 10){break};if($probeHeader.Length -ge 16384){throw 'Git returned an invalid initialization response.'};[void]$probeHeader.Append([char]$byte)}
        if(-not $probeHeader.ToString().EndsWith(' missing')){throw 'Git batch process returned an unexpected initialization response.'}
        foreach($entry in $Entries){
            $path=[string]$entry.RelativePath
            if([string]::IsNullOrWhiteSpace($path) -or $path.Contains("`n") -or $path.Contains("`r")){throw 'A Git path cannot be read by the batch exporter.'}
            $request=[Text.Encoding]::UTF8.GetBytes($Commit+':'+$path+"`n")
            $inputStream.Write($request,0,$request.Length);$inputStream.Flush()
            $header=New-Object Text.StringBuilder
            while($true){
                $byte=$output.ReadByte()
                if($byte -lt 0){throw "Git stopped while reading '$path'."}
                if($byte -eq 10){break}
                if($header.Length -ge 16384){throw 'Git returned an invalid batch header.'}
                [void]$header.Append([char]$byte)
            }
            $headerText=$header.ToString()
            if($headerText -notmatch '^[0-9a-fA-F]{40,64} blob ([0-9]+)$'){throw "Git could not read '$path' as a file: $headerText"}
            [long]$remaining=$Matches[1]
            $file=[IO.File]::Open($entry.Destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
            try {
                while($remaining -gt 0){
                    $length=[int][Math]::Min([long]$buffer.Length,$remaining)
                    $read=$output.Read($buffer,0,$length)
                    if($read -le 0){throw "Git returned incomplete content for '$path'."}
                    $file.Write($buffer,0,$read);$remaining-=$read
                }
            } finally {$file.Dispose()}
            if($output.ReadByte() -ne 10){throw "Git returned invalid content framing for '$path'."}
        }
        $process.StandardInput.Close();$process.WaitForExit();$stderr=$stderrTask.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "Git batch export failed: $stderr"}
    } finally {
        try {$process.StandardInput.Close()}catch{}
        if(-not $process.HasExited){if(-not $process.WaitForExit(1000)){$process.Kill();$process.WaitForExit()}}
        $process.Dispose()
    }
}

function Export-DeliveryGitBlob {
    param([string]$Repository,[string]$Commit,[string]$RelativePath,[string]$Destination)
    if($Commit -notmatch '^[0-9a-fA-F]{40,64}$'){throw 'Invalid Git commit identifier.'}
    if([string]::IsNullOrWhiteSpace($RelativePath)){throw 'Git file path is missing.'}
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName='git';$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.CreateNoWindow=$true
    $psi.Arguments='-c safe.directory="'+$Repository+'" -C "'+$Repository+'" show "'+$Commit+':'+$RelativePath.Replace('"','\"')+'"'
    $process=[Diagnostics.Process]::Start($psi)
    try {
        $stderrTask=$process.StandardError.ReadToEndAsync()
        $file=[IO.File]::Open($Destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        try {$process.StandardOutput.BaseStream.CopyTo($file)} finally {$file.Dispose()}
        $process.WaitForExit();$err=$stderrTask.GetAwaiter().GetResult()
        if($process.ExitCode -ne 0){throw "Could not read '$RelativePath' at commit $Commit : $err"}
    } finally {$process.Dispose()}
}

function New-DeliveryGitDiffFiles {
    param([Parameter(Mandatory)]$Metadata)
    if(-not (Test-Path -LiteralPath $Metadata.Repository -PathType Container)){throw 'The original Git repository is unavailable.'}
    $folder=Join-Path ([IO.Path]::GetTempPath()) ('delivery-diff-'+[Guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $folder -ErrorAction Stop)
    $extension=[IO.Path]::GetExtension($Metadata.ComparePath)
    $left=Join-Path $folder ('base'+$extension);$right=Join-Path $folder ('compare'+$extension)
    if($Metadata.BasePath){Export-DeliveryGitBlob $Metadata.Repository $Metadata.BaseCommit $Metadata.BasePath $left}else{[IO.File]::WriteAllBytes($left,[byte[]]@())}
    Export-DeliveryGitBlob $Metadata.Repository $Metadata.CompareCommit $Metadata.ComparePath $right
    return [pscustomobject]@{Root=$folder;BaseFile=$left;CompareFile=$right}
}

function Find-DeliveryTortoiseGitMerge {
    $command=Get-Command 'TortoiseGitMerge.exe' -ErrorAction SilentlyContinue
    if($command -and $command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)){return $command.Source}
    foreach($root in @(${env:ProgramFiles},${env:ProgramFiles(x86)})){
        if($root){$candidate=Join-Path $root 'TortoiseGit\bin\TortoiseGitMerge.exe';if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}}
    }
    return $null
}

function Get-DeliveryTortoiseArguments {
    param([Parameter(Mandatory)]$Metadata,[Parameter(Mandatory)]$Files)
    $baseLabel=if($Metadata.BasePath){$Metadata.BaseBranch+' ('+$Metadata.BaseCommit.Substring(0,8)+') - '+$Metadata.BasePath}else{$Metadata.BaseBranch+' - new file'}
    $compareLabel=$Metadata.CompareBranch+' ('+$Metadata.CompareCommit.Substring(0,8)+') - '+$Metadata.ComparePath
    # Windows filenames cannot contain quotes; branch labels are display-only and must not break arguments.
    $baseLabel=$baseLabel.Replace('"',"'");$compareLabel=$compareLabel.Replace('"',"'")
    return @('/readonly',('/base:"{0}"' -f $Files.BaseFile),('/mine:"{0}"' -f $Files.CompareFile),('/basename:"{0}"' -f $baseLabel),('/minename:"{0}"' -f $compareLabel))
}

function Get-DeliveryGitBranches {
    param([Parameter(Mandatory)][string]$Repository)
    Sync-DeliveryGitRemote $Repository
    return @(Invoke-DeliveryGit $Repository @('branch', '--all', '--no-color', '--format=%(refname:short)') | Where-Object { $_ })
}

function Resolve-DeliveryGitRef {
    param([Parameter(Mandatory)][string]$Repository,[Parameter(Mandatory)][string]$Reference)
    $clean = $Reference.Trim()
    $upstreamRes = Invoke-DeliveryGitRaw $Repository @('rev-parse', '--abbrev-ref', ($clean + '@{upstream}'))
    if ($upstreamRes.ExitCode -eq 0 -and $upstreamRes.Output.Count -and $upstreamRes.Output[0]) {
        $candidate = $upstreamRes.Output[0].Trim()
        if ($candidate -and $candidate -notmatch 'fatal:') { return $candidate }
    }
    $verifyRes = Invoke-DeliveryGitRaw $Repository @('rev-parse', '--verify', $clean)
    if ($verifyRes.ExitCode -eq 0) { return $clean }
    $remoteVerify = Invoke-DeliveryGitRaw $Repository @('rev-parse', '--verify', "origin/$clean")
    if ($remoteVerify.ExitCode -eq 0) { return "origin/$clean" }
    return $clean
}

function Invoke-DeliveryGitCheckoutAndPull {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$BranchName
    )
    Sync-DeliveryGitRemote $Repository

    $branch = $BranchName.Trim()
    if ($branch.StartsWith('origin/')) {
        $branch = $branch.Substring(7)
    }

    # Stash uncommitted changes if repository is dirty
    $statusRes = Invoke-DeliveryGitRaw $Repository @('status', '--porcelain')
    if ($statusRes.ExitCode -eq 0 -and $statusRes.Output.Count -gt 0) {
        [void](Invoke-DeliveryGitRaw $Repository @('stash', 'push', '-m', 'GOM auto-stash before checkout'))
    }

    # Check current branch
    $currentRes = Invoke-DeliveryGitRaw $Repository @('branch', '--show-current')
    $currentBranch = if ($currentRes.ExitCode -eq 0 -and $currentRes.Output.Count) { $currentRes.Output[0].Trim() } else { '' }

    if ($currentBranch -ne $branch) {
        # Checkout branch
        $checkoutRes = Invoke-DeliveryGitRaw $Repository @('checkout', $branch)
        if ($checkoutRes.ExitCode -ne 0) {
            # Try checking out from origin tracking
            $trackRes = Invoke-DeliveryGitRaw $Repository @('checkout', '-B', $branch, "origin/$branch")
            if ($trackRes.ExitCode -ne 0) {
                # Stderr is not fatal if already checked out or detached
            }
        }
    }

    # Pull latest changes from remote if remote exists
    $pullRes = Invoke-DeliveryGitRaw $Repository @('pull')
    if ($pullRes.ExitCode -ne 0) {
        [void](Invoke-DeliveryGitRaw $Repository @('pull', 'origin', $branch))
    }

    return $branch
}

function ConvertFrom-DeliveryGitNameStatus {
    param([string[]]$Lines,[string]$Repository)
    $result = @{}
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 2) { continue }
        $status = $parts[0].Trim()
        $relative = if ($status.StartsWith('R') -or $status.StartsWith('C')) { $parts[$parts.Count - 1] } else { $parts[1] }
        if ($relative) { $result[[IO.Path]::GetFullPath((Join-Path -Path $Repository -ChildPath $relative.Trim()))] = $status }
    }
    return $result
}

function Merge-DeliveryGitChanges {
    param([Parameter(Mandatory)][hashtable]$Target,[Parameter(Mandatory)][hashtable]$Incoming)
    foreach ($path in $Incoming.Keys) { $Target[$path] = $Incoming[$path] }
}

function Get-DeliveryGitChanges {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$BaseBranch,
        [Parameter(Mandatory)][string]$CompareBranch,
        [bool]$IncludeWorkspace = $false,
        [bool]$SyncRemote = $true,
        [bool]$AutoCheckoutAndPull = $false
    )
    if ($AutoCheckoutAndPull) {
        [void](Invoke-DeliveryGitCheckoutAndPull -Repository $Repository -BranchName $CompareBranch)
    } elseif ($SyncRemote) {
        Sync-DeliveryGitRemote $Repository
    }

    $base = Resolve-DeliveryGitRef $Repository $BaseBranch
    $compare = Resolve-DeliveryGitRef $Repository $CompareBranch
    $changes = ConvertFrom-DeliveryGitNameStatus @(Invoke-DeliveryGit $Repository @('diff', '--name-status', '-M', '--diff-filter=ACMR', ($base + '...' + $compare))) $Repository
    if ($IncludeWorkspace) {
        foreach ($line in @(Invoke-DeliveryGit $Repository @('diff', '--name-status', '-M', 'HEAD'))) { Merge-DeliveryGitChanges $changes (ConvertFrom-DeliveryGitNameStatus @($line) $Repository) }
        foreach ($line in @(Invoke-DeliveryGit $Repository @('diff', '--name-status', '-M', '--cached'))) { Merge-DeliveryGitChanges $changes (ConvertFrom-DeliveryGitNameStatus @($line) $Repository) }
        foreach ($relative in @(Invoke-DeliveryGit $Repository @('ls-files', '--others', '--exclude-standard'))) {
            if ($relative) { $changes[[IO.Path]::GetFullPath((Join-Path -Path $Repository -ChildPath $relative.Trim()))] = 'A' }
        }
    }
    return [pscustomobject]@{ Base = $base; Compare = $compare; Changes = $changes }
}
