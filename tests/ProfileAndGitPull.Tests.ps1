$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Core.Git.ps1')
. (Join-Path $root 'Core.FileOps.ps1')
. (Join-Path $root 'Core.SqlPlus.ps1')

if ((ConvertTo-DeliveryBranchFolderName 'feature/branch1') -ne 'feature-branch1') {
    throw 'Compare branch folder name must replace path separators with hyphens'
}
if ((ConvertTo-DeliveryBranchFolderName 'release:2026') -ne 'release-2026') {
    throw 'Compare branch folder name must replace invalid Windows filename characters'
}
if (ConvertTo-DeliveryBranchFolderName '') {
    throw 'An empty compare branch must not create an extra delivery folder'
}

$temp = Join-Path $env:TEMP ('delivery-test-'+[Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $sourceDir = Join-Path $temp 'src'
    New-Item -ItemType Directory -Path $sourceDir | Out-Null

    # Create dummy BVSC source structure
    $bvscHostView = Join-Path $sourceDir '2.HOST\1.View\V_TEST.sql'
    $bvscHostChange = Join-Path $sourceDir '2.HOST\0.ChangeScripts\01.CREATE_TABLE.sql'
    $bvscReport = Join-Path $sourceDir '5.Reports\SE2305.rpt'
    $bdsParam = Join-Path $sourceDir '1.BDSHOST\Parameters\ALLCODE\BDS_ALLCODE.sql'
    $serviceDll = Join-Path $sourceDir '3.Service\Host.dll'

    New-Item -ItemType Directory -Path (Split-Path $bvscHostView) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $bvscHostChange) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $bvscReport) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $bdsParam) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $serviceDll) -Force | Out-Null

    Set-Content -LiteralPath $bvscHostView -Value 'CREATE OR REPLACE VIEW V_TEST AS SELECT 1 FROM DUAL;'
    Set-Content -LiteralPath $bvscHostChange -Value 'CREATE TABLE TEST_TB (ID NUMBER);'
    Set-Content -LiteralPath $bvscReport -Value 'DUMMY RPT CONTENT'
    Set-Content -LiteralPath $bdsParam -Value 'INSERT INTO ALLCODE VALUES (''A'');'
    Set-Content -LiteralPath $serviceDll -Value 'DLL CONTENT'

    # Test 1: BVSC Profile Relative Path Mapping
    $relView = Get-DeliveryRelativePath -Source $sourceDir -Path $bvscHostView -PreserveStructure $true -Profile 'BVSC'
    if ($relView -ne '2.HOST\upgrade\sql\2.HOST\1.View\V_TEST.sql') {
        throw "BVSC mapping failed for View: got $relView"
    }

    $relChange = Get-DeliveryRelativePath -Source $sourceDir -Path $bvscHostChange -PreserveStructure $true -Profile 'BVSC'
    if ($relChange -ne '2.HOST\upgrade\sql\2.HOST\0.ChangeScripts\01.CREATE_TABLE.sql') {
        throw "BVSC mapping failed for ChangeScripts: got $relChange"
    }

    $relReport = Get-DeliveryRelativePath -Source $sourceDir -Path $bvscReport -PreserveStructure $true -Profile 'BVSC'
    if ($relReport -ne '5.Reports\SE2305.rpt') {
        throw "BVSC mapping failed for Report: got $relReport"
    }

    # Test 2: Standard Profile Relative Path Mapping
    $relStdParam = Get-DeliveryRelativePath -Source $sourceDir -Path $bdsParam -PreserveStructure $true -Profile 'Standard'
    if ($relStdParam -ne '1.BDSHOST\Parameters\ALLCODE\BDS_ALLCODE.sql') {
        throw "Standard mapping failed for BDS Param: got $relStdParam"
    }

    $relStdDll = Get-DeliveryRelativePath -Source $sourceDir -Path $serviceDll -PreserveStructure $true -Profile 'Standard'
    if ($relStdDll -ne '3.Service\Host.dll') {
        throw "Standard mapping failed for Service: got $relStdDll"
    }

    # Test 3: BVSC Delivery Scripts Generation
    $bvscDest = Join-Path $temp 'bvsc_dest'
    $item1 = New-DeliveryItem -File (Get-Item $bvscHostChange) -Source $sourceDir -Profile 'BVSC'
    $item2 = New-DeliveryItem -File (Get-Item $bvscHostView) -Source $sourceDir -Profile 'BVSC'
    $item3 = New-DeliveryItem -File (Get-Item $bvscReport) -Source $sourceDir -Profile 'BVSC'

    $copyRes = Copy-DeliveryFiles -Items @($item1, $item2, $item3) -Destination $bvscDest -DuplicateMode Overwrite -VerifyHash $true -ReportProgress {param($d,$t,$m)} -IsCancelled {$false}
    $scriptRes = New-DeliveryRunScript -Items $copyRes.Items -Destination $bvscDest -DbUser 'HOSTBVSFUND' -DbPass 'HOST' -TnsName 'FLEX_236' -Profile 'BVSC'

    if ($copyRes.ManifestPath) {
        throw 'delivery_manifest must not be created for BVSC delivery'
    }

    if (-not (Test-Path -LiteralPath (Join-Path $bvscDest '2.HOST\upgrade\cmd\runUpdate.bat'))) {
        throw 'runUpdate.bat missing in BVSC package'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $bvscDest '2.HOST\upgrade\cmd\setVariable.bat'))) {
        throw 'setVariable.bat missing in BVSC package'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $bvscDest '2.HOST\upgrade\log'))) {
        throw 'log directory missing in BVSC package'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $bvscDest '2.HOST\upgrade\sql\install.sql'))) {
        throw 'install.sql missing in BVSC package'
    }
    $templateRoot = Join-Path $root 'Assets\BVSC'
    $updateGuide = Join-Path $bvscDest 'Huong_dan_cap_nhat.txt'
    $runAllGuide = Join-Path $bvscDest '2.HOST\upgrade\Huong dan runall.sql'
    if ((Get-FileHash -LiteralPath $updateGuide).Hash -ne (Get-FileHash -LiteralPath (Join-Path $templateRoot 'Huong_dan_cap_nhat.txt')).Hash) {
        throw 'Huong_dan_cap_nhat.txt was not copied from the BVSC template'
    }
    if ((Get-FileHash -LiteralPath $runAllGuide).Hash -ne (Get-FileHash -LiteralPath (Join-Path $templateRoot 'Huong dan runall.sql')).Hash) {
        throw 'Huong dan runall.sql was not copied from the BVSC template'
    }

    $installContent = Get-Content -LiteralPath (Join-Path $bvscDest '2.HOST\upgrade\sql\install.sql') -Raw
    if ($installContent -notmatch '@@2\.HOST/0\.ChangeScripts/01\.CREATE_TABLE\.sql') {
        throw 'install.sql does not contain @@2.HOST/0.ChangeScripts/01.CREATE_TABLE.sql'
    }
    if ($installContent -notmatch '@@2\.HOST/1\.View/V_TEST\.sql') {
        throw 'install.sql does not contain @@2.HOST/1.View/V_TEST.sql'
    }
    $bvscRunscript = Get-Content -LiteralPath (Join-Path $bvscDest '2.HOST\upgrade\runscript.txt') -Raw
    if (-not $bvscRunscript.Contains('@' + $bvscHostView)) {
        throw 'BVSC runscript.txt must use the absolute local-repository path for V_TEST.sql'
    }
    if (-not $bvscRunscript.Contains('SPOOL D:/log.txt;')) {
        throw 'BVSC runscript.txt must spool to D:/log.txt'
    }

    # Test 4: BSC Delivery Scripts Generation
    $stdDest = Join-Path $temp 'std_dest'
    $stdItem1 = New-DeliveryItem -File (Get-Item $bdsParam) -Source $sourceDir -Profile 'BSC'
    $stdItem2 = New-DeliveryItem -File (Get-Item $bvscHostChange) -Source $sourceDir -Profile 'BSC'
    $stdItem3 = New-DeliveryItem -File (Get-Item $serviceDll) -Source $sourceDir -Profile 'BSC'

    $stdCopyRes = Copy-DeliveryFiles -Items @($stdItem1, $stdItem2, $stdItem3) -Destination $stdDest -DuplicateMode Overwrite -VerifyHash $true -WriteManifest $false -ReportProgress {param($d,$t,$m)} -IsCancelled {$false}
    $stdScriptRes = New-DeliveryRunScript -Items $stdCopyRes.Items -Destination $stdDest -DbUser 'HOSTBSCFUND' -DbPass 'HOST' -TnsName 'FLEX189' -Profile 'BSC'

    if (-not (Test-Path -LiteralPath (Join-Path $stdDest 'runscript.txt'))) {
        throw 'runscript.txt missing in BSC package'
    }
    $stdRunscript = Get-Content -LiteralPath (Join-Path $stdDest 'runscript.txt') -Raw
    if (-not $stdRunscript.Contains('@' + $bdsParam)) {
        throw 'runscript.txt must use the absolute local-repository path for BDS_ALLCODE.sql'
    }
    if (-not $stdRunscript.Contains('SPOOL D:/log.txt;')) {
        throw 'BSC runscript.txt must spool to D:/log.txt'
    }
    if (Test-Path -LiteralPath (Join-Path $stdDest 'runscript.sql')) {
        throw 'runscript.sql must not be created for BSC delivery'
    }
    if ($stdCopyRes.ManifestPath) {
        throw 'delivery_manifest must not be created for BSC delivery'
    }

    # Test 5: Git Auto Checkout and Pull
    $gitRepo = Join-Path $temp 'git_repo'
    New-Item -ItemType Directory -Path $gitRepo | Out-Null
    & git -C $gitRepo init -q
    & git -C $gitRepo checkout -qb main
    Set-Content -LiteralPath (Join-Path $gitRepo 'base.txt') -Value 'base'
    & git -C $gitRepo add base.txt
    & git -C $gitRepo -c user.name=Test -c user.email=test@test.com commit -qm 'initial'

    & git -C $gitRepo checkout -qb feature/branch1
    Set-Content -LiteralPath (Join-Path $gitRepo 'feature.txt') -Value 'feature'
    & git -C $gitRepo add feature.txt
    & git -C $gitRepo -c user.name=Test -c user.email=test@test.com commit -qm 'feature commit'

    # Switch back to main
    & git -C $gitRepo checkout main -q

    # Now verify current branch is main
    $currentBefore = @(& git -C $gitRepo branch --show-current)[0].Trim()
    if ($currentBefore -ne 'main') {
        throw "Expected branch 'main', got '$currentBefore'"
    }

    # Run Get-DeliveryGitChanges with AutoCheckoutAndPull = $true for feature/branch1
    $changes = Get-DeliveryGitChanges -Repository $gitRepo -BaseBranch 'main' -CompareBranch 'feature/branch1' -AutoCheckoutAndPull $true
    
    $currentAfter = @(& git -C $gitRepo branch --show-current)[0].Trim()
    if ($currentAfter -ne 'feature/branch1') {
        throw "Auto checkout failed! Current branch should be 'feature/branch1', but got '$currentAfter'"
    }

    $featurePath = Join-Path $gitRepo 'feature.txt'
    if (-not (Test-Path -LiteralPath $featurePath -PathType Leaf)) {
        throw "feature.txt does not exist on local disk after auto checkout!"
    }

    Write-Host "All tests passed successfully!" -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
