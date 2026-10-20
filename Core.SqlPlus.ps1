Set-StrictMode -Version Latest

function New-BvscDeliveryScripts {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Destination,
        [string]$SourceRoot = '',
        [string]$DbUser = 'HOSTBVSFUND',
        [string]$DbPass = 'HOST',
        [string]$TnsName = 'FLEX_236',
        [string]$LogFile = '../log/install.log'
    )
    $upgradeDir = Join-Path $Destination '2.HOST\upgrade'
    $cmdDir = Join-Path $upgradeDir 'cmd'
    $logDir = Join-Path $upgradeDir 'log'
    $sqlDir = Join-Path $upgradeDir 'sql'

    New-Item -ItemType Directory -Path $cmdDir -Force | Out-Null
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    New-Item -ItemType Directory -Path $sqlDir -Force | Out-Null

    $templateRoot = Join-Path $PSScriptRoot 'Assets\BVSC'
    $updateGuideTemplate = Join-Path $templateRoot 'Huong_dan_cap_nhat.txt'
    $runAllGuideTemplate = Join-Path $templateRoot 'Huong dan runall.sql'
    foreach ($template in @($updateGuideTemplate, $runAllGuideTemplate)) {
        if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
            throw "Required BVSC template was not found: $template"
        }
    }
    Copy-Item -LiteralPath $updateGuideTemplate -Destination (Join-Path $Destination 'Huong_dan_cap_nhat.txt') -Force
    Copy-Item -LiteralPath $runAllGuideTemplate -Destination (Join-Path $upgradeDir 'Huong dan runall.sql') -Force

    # 1. cmd\runUpdate.bat
    $runUpdateContent = @"
rem database user
call setVariable.bat
rem begin invoke sql master file
cd ..\sql
sqlplus %HOST_USER%/%HOST_PASSW_USER%@%FLEX_TNSNAMES% @install.sql

pause
"@
    Set-Content -LiteralPath (Join-Path $cmdDir 'runUpdate.bat') -Value $runUpdateContent -Encoding ASCII

    # 2. cmd\setVariable.bat
    $setVariableContent = @"
rem database user
set HOST_USER=$DbUser
set HOST_PASSW_USER=$DbPass
set FLEX_TNSNAMES=$TnsName

"@
    Set-Content -LiteralPath (Join-Path $cmdDir 'setVariable.bat') -Value $setVariableContent -Encoding ASCII

    # 3. sql\install.sql
    $copiedSql = @($Items | Where-Object {
        $_.ActualDestination -and $_.Status -match '^Copied' -and [IO.Path]::GetExtension($_.ActualDestination).Equals('.sql', [StringComparison]::OrdinalIgnoreCase)
    } | Sort-Object { Get-DeliverySqlPriority $_.ActualDestination }, { $_.ActualDestination })

    $sqlCalls = New-Object System.Collections.Generic.List[string]
    $runscriptCalls = New-Object System.Collections.Generic.List[string]

    foreach ($item in $copiedSql) {
        $act = $item.ActualDestination.Replace('/', '\')
        # install.sql uses relative path (@@) from the sql/ dir
        if ($act -match '2\.HOST\\upgrade\\sql\\(?<subSql>.*)$') {
            $sub = $Matches['subSql'].Replace('\', '/')
            [void]$sqlCalls.Add("@@$sub")
        } else {
            [void]$sqlCalls.Add('@@' + $act.Replace('\', '/'))
        }
        # runscript.txt runs scripts directly from the local repository.
        if ($item.PSObject.Properties['Source'] -and $item.Source) {
            [void]$runscriptCalls.Add('@' + [IO.Path]::GetFullPath($item.Source))
        } else {
            # Fallback for callers that only provide the copied destination.
            [void]$runscriptCalls.Add('@' + (Join-Path $Destination $act))
        }
    }

    $installContent = @(
        'SET TRUNC OFF',
        'SET HEADING ON',
        'SET DEFINE OFF',
        '',
        "SPO $LogFile;"
    ) + $sqlCalls + @(
        'COMMIT;',
        '',
        'exit'
    )
    $installPath = Join-Path $sqlDir 'install.sql'
    $installContent | Set-Content -LiteralPath $installPath -Encoding UTF8

    # 4. runscript.txt - named after source root folder
    $runscriptName = if ($SourceRoot) { [IO.Path]::GetFileName($SourceRoot.TrimEnd('\/', ' ')) } else { 'runscript' }
    $runscriptContent = @(
        'SET TRUNC OFF',
        'SET HEADING OFF',
        'SET ECHO OFF',
        'SET DEFINE OFF',
        'SET FEEDBACK OFF',
        'SET VERIFY OFF',
        'SET TERMOUT OFF',
        'SPOOL D:/log.txt;',
        "conn $DbUser/$DbPass@$TnsName;"
    ) + $runscriptCalls + @(
        'COMMIT;',
        'SPOOL OFF;'
    )
    $runscriptPath = Join-Path $upgradeDir "$runscriptName.txt"
    $runscriptContent | Set-Content -LiteralPath $runscriptPath -Encoding UTF8

    return [pscustomobject]@{
        InstallSql = $installPath
        RunUpdateBat = (Join-Path $cmdDir 'runUpdate.bat')
        RunscriptTxt = $runscriptPath
        UpdateGuide = (Join-Path $Destination 'Huong_dan_cap_nhat.txt')
        RunAllGuide = (Join-Path $upgradeDir 'Huong dan runall.sql')
    }
}

function New-StandardDeliveryScripts {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Destination,
        [string]$DbUser = 'HOSTBSCFUND',
        [string]$DbPass = 'HOST',
        [string]$TnsName = 'FLEX189',
        [string]$LogFile = '../log/install.log'
    )
    $copiedSql = @($Items | Where-Object {
        $_.ActualDestination -and $_.Status -match '^Copied' -and [IO.Path]::GetExtension($_.ActualDestination).Equals('.sql', [StringComparison]::OrdinalIgnoreCase)
    } | Sort-Object { Get-DeliverySqlPriority $_.ActualDestination }, { $_.ActualDestination })

    if (-not $copiedSql.Count) { return $null }

    $sqlCalls = @($copiedSql | ForEach-Object {
        # BSC runs directly from the local repository, so retain the source's absolute path.
        $scriptPath = if ($_.PSObject.Properties['Source'] -and $_.Source) {
            [IO.Path]::GetFullPath($_.Source)
        } else {
            Join-Path $Destination $_.ActualDestination
        }
        '@' + $scriptPath
    })

    $runscriptContent = @(
        'SET TRUNC OFF',
        'SET HEADING OFF',
        'SET ECHO OFF',
        'SET DEFINE OFF',
        'SET FEEDBACK OFF',
        'SET VERIFY OFF',
        'SET TERMOUT OFF',
        'SPOOL D:/log.txt;',
        "conn $DbUser/$DbPass@$TnsName;"
    ) + $sqlCalls + @(
        'COMMIT;',
        'SPOOL OFF;'
    )

    $runscriptPath = Join-Path $Destination 'runscript.txt'
    $runscriptContent | Set-Content -LiteralPath $runscriptPath -Encoding UTF8

    return $runscriptPath
}

function New-DeliveryRunScript {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$DbUser,
        [Parameter(Mandatory)][string]$TnsName,
        [string]$DbPass = 'HOST',
        [string]$LogFile = '../log/install.log',
        [string]$Profile = 'BVSC'
    )
    if ([string]::IsNullOrWhiteSpace($DbUser) -or [string]::IsNullOrWhiteSpace($TnsName)) {
        throw 'DB User and TNS name are required.'
    }
    if ($Profile -eq 'BVSC') {
        $res = New-BvscDeliveryScripts -Items $Items -Destination $Destination -DbUser $DbUser -DbPass $DbPass -TnsName $TnsName -LogFile $LogFile
        return $res.InstallSql
    } else {
        return (New-StandardDeliveryScripts -Items $Items -Destination $Destination -DbUser $DbUser -DbPass $DbPass -TnsName $TnsName -LogFile $LogFile)
    }
}
