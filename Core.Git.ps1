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
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    $lines = New-Object System.Collections.Generic.List[string]
    if ($stdout) {
        foreach ($line in ($stdout -split "`r?`n")) {
            $t = $line.Trim()
            if ($t) { [void]$lines.Add($t) }
        }
    }

    return [pscustomobject]@{
        ExitCode = $proc.ExitCode
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
        [void](Invoke-DeliveryGitRaw $Repository @('fetch', '--all', '--prune'))
    }
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
