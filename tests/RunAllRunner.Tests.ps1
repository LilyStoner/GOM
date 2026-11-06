$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'Core.Runner.ps1')
$temp=Join-Path $env:TEMP ('delivery-runner-test-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
$outputs=@()
$oldPath=$null
try {
    $exe=Join-Path $temp 'sqlplus.exe'
    $source=@'
using System;
using System.IO;
public static class FakeSqlPlus {
  public static int Main(string[] args) {
    string input=Console.In.ReadToEnd();
    if (!input.Contains("whenever sqlerror exit sql.sqlcode rollback")) return 91;
    string mode=Environment.GetEnvironmentVariable("DELIVERY_FAKE_MODE");
    string log=Environment.GetEnvironmentVariable("DELIVERY_FAKE_LOG");
    if (mode=="success") { File.WriteAllText(log,"SQL ran successfully"); Console.WriteLine("done"); return 0; }
    if (mode=="sql-error") { File.WriteAllText(log,"ORA-00942: table or view does not exist"); return 0; }
    if (mode=="exit-error") { Console.Error.WriteLine("SP2-0310: unable to open file"); return 2; }
    return 0;
  }
}
'@
    Add-Type -TypeDefinition $source -OutputAssembly $exe -OutputType ConsoleApplication
    $scriptFile=Join-Path $temp 'script with spaces.sql';[IO.File]::WriteAllText($scriptFile,'test')
    $env:DELIVERY_FAKE_LOG=Join-Path $temp 'run.log'
    foreach($case in @(@('success','Completed'),@('sql-error','Failed'),@('exit-error','Failed'),@('no-log','Unverified'))){
        if(Test-Path $env:DELIVERY_FAKE_LOG){Remove-Item $env:DELIVERY_FAKE_LOG}
        $env:DELIVERY_FAKE_MODE=$case[0]
        $res=Invoke-DeliverySqlPlusProcess -Executable $exe -ScriptPath $scriptFile -Profile Other -User u -Password p -Tns t -LogPath $env:DELIVERY_FAKE_LOG
        $outputs+=@($res.OutputPath,$res.ErrorPath)
        if($res.Status -ne $case[1]){throw "Wrong status for $($case[0]): $($res.Status)"}
        if($case[0] -eq 'sql-error' -and $res.Issues[0] -notmatch '^ORA-00942'){throw 'SQL error from the spool log was not reported'}
    }
    [IO.File]::WriteAllText($env:DELIVERY_FAKE_LOG,'old successful log')
    $env:DELIVERY_FAKE_MODE='no-log'
    $stale=Invoke-DeliverySqlPlusProcess -Executable $exe -ScriptPath $scriptFile -Profile Other -User u -Password p -Tns t -LogPath $env:DELIVERY_FAKE_LOG
    $outputs+=@($stale.OutputPath,$stale.ErrorPath)
    if($stale.Status -ne 'Unverified'){throw 'An unchanged log from a previous run must not count as success'}
    . (Join-Path (Split-Path $PSScriptRoot) 'App.ps1') -NoShow
    $oldPath=$env:PATH;$env:PATH=$temp+';'+$env:PATH
    $script:db.Log=$env:DELIVERY_FAKE_LOG
    foreach($case in @(@('success','completed'),@('sql-error','failed'),@('no-log','not updated'))){
        if(Test-Path $env:DELIVERY_FAKE_LOG){Remove-Item $env:DELIVERY_FAKE_LOG}
        $env:DELIVERY_FAKE_MODE=$case[0]
        Invoke-RunAll -RunScriptPath $scriptFile -Profile Other -Dest $temp
        if($RunAllPanel.Visibility -ne 'Visible' -or $RunAllProgress.Visibility -ne 'Visible'){throw 'Run All must show in-app progress'}
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while($script:backgroundOperation -and $watch.Elapsed.TotalSeconds -lt 20){Complete-DeliveryBackground;Start-Sleep -Milliseconds 20}
        if($script:backgroundOperation){throw 'Run All did not finish'}
        if($RunAllStatus.Text -notmatch $case[1]){throw "Wrong in-app status for $($case[0]): $($RunAllStatus.Text)"}
        if($RunAllProgress.Visibility -ne 'Collapsed' -or $ViewRunLogButton.Visibility -ne 'Visible'){throw 'Run All must expose its log and stop progress when finished'}
        $outputs+=@($script:runAllOutputPath,$script:runAllErrorPath)
    }
    Write-Host 'Run All process tests passed: success, SQL error, process error, and missing log.'
} finally {
    foreach($file in $outputs){if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force}}
    Remove-Item Env:DELIVERY_FAKE_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:DELIVERY_FAKE_LOG -ErrorAction SilentlyContinue
    if($oldPath){$env:PATH=$oldPath}
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
