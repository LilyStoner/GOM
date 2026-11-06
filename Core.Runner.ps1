Set-StrictMode -Version Latest

function Invoke-DeliverySqlPlusProcess {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$Profile,
        [Parameter(Mandatory)][string]$User,
        [AllowEmptyString()][string]$Password,
        [Parameter(Mandatory)][string]$Tns,
        [string]$LogPath
    )
    if(-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)){throw "Script file not found: $ScriptPath"}
    foreach($value in @($ScriptPath,$User,$Password,$Tns)) { if($value -match '[\r\n]'){throw 'SQL*Plus arguments cannot contain newlines.'} }
    if($ScriptPath.Contains('"')){throw 'SQL script path cannot contain a quote.'}
    $working=Split-Path -Parent $ScriptPath
    if($LogPath -and -not [IO.Path]::IsPathRooted($LogPath)){$LogPath=Join-Path $working $LogPath}
    $output=Join-Path ([IO.Path]::GetTempPath()) ('delivery-sql-output-'+[guid]::NewGuid().ToString('N')+'.log')
    $errors=Join-Path ([IO.Path]::GetTempPath()) ('delivery-sql-error-'+[guid]::NewGuid().ToString('N')+'.log')
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$Executable;$psi.Arguments='-L -s /nolog';$psi.WorkingDirectory=$working
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $outFile=$null;$errFile=$null;$process=$null;$finished=$false
    $started=[DateTime]::UtcNow
    $previousLog=$null
    if($LogPath -and (Test-Path -LiteralPath $LogPath -PathType Leaf)){
        $item=Get-Item -LiteralPath $LogPath
        $previousLog=[pscustomobject]@{Ticks=$item.LastWriteTimeUtc.Ticks;Length=$item.Length}
    }
    try {
        $outFile=[IO.File]::Open($output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
        $errFile=[IO.File]::Open($errors,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
        $process=[Diagnostics.Process]::Start($psi)
        $outTask=$process.StandardOutput.BaseStream.CopyToAsync($outFile)
        $errTask=$process.StandardError.BaseStream.CopyToAsync($errFile)
        $input=$process.StandardInput
        $input.WriteLine('set echo off')
        $input.WriteLine('whenever oserror exit failure rollback')
        $input.WriteLine('whenever sqlerror exit sql.sqlcode rollback')
        if($Profile -eq 'BVSC'){$input.WriteLine(('connect '+$User+'/'+$Password+'@'+$Tns))}
        $input.WriteLine(('@"'+$ScriptPath+'"'))
        $input.WriteLine('exit')
        $input.Close()
        $process.WaitForExit();[void]$outTask.GetAwaiter().GetResult();[void]$errTask.GetAwaiter().GetResult()
        $outFile.Dispose();$outFile=$null;$errFile.Dispose();$errFile=$null
        $issues=New-Object 'System.Collections.Generic.List[string]'
        $logCurrent=$false
        if($LogPath -and (Test-Path -LiteralPath $LogPath -PathType Leaf)){
            $item=Get-Item -LiteralPath $LogPath
            $logCurrent=$item.LastWriteTimeUtc -ge $started.AddSeconds(-2)
            if($previousLog -and $item.LastWriteTimeUtc.Ticks -eq $previousLog.Ticks -and $item.Length -eq $previousLog.Length){$logCurrent=$false}
        }
        $scan=@($output,$errors);if($logCurrent){$scan+= $LogPath}
        foreach($file in $scan){
            $reader=[IO.File]::OpenText($file)
            try {while($null -ne ($line=$reader.ReadLine())){if($line -match '(?i)^\s*(ORA-\d+|SP2-\d+|TNS-\d+|PLS-\d+|warning:.*compilation errors)') {if($issues.Count -lt 10){[void]$issues.Add($line.Trim())}}}}finally{$reader.Dispose()}
        }
        $status=if($process.ExitCode -ne 0 -or $issues.Count){'Failed'}elseif(-not $logCurrent){'Unverified'}else{'Completed'}
        $finished=$true
        return [pscustomobject]@{Status=$status;ExitCode=$process.ExitCode;Issues=@($issues.ToArray());OutputPath=$output;ErrorPath=$errors;LogPath=$(if($logCurrent){$LogPath}else{$null})}
    } finally {
        if($process){if(-not $process.HasExited){try{$process.Kill()}catch{}};$process.Dispose()}
        if($outFile){$outFile.Dispose()};if($errFile){$errFile.Dispose()}
        if(-not $finished){Remove-Item -LiteralPath $output,$errors -Force -ErrorAction SilentlyContinue}
    }
}
