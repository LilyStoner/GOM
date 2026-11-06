$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'Core.WindowSettings.ps1')
$dir=Join-Path $env:TEMP ('delivery-window-test-'+[guid]::NewGuid().ToString('N'))
$path=Join-Path $dir 'window.json'
try {
    $size=Get-DeliveryWindowSize $path 1920 1040
    if($size.Width -ne 1040 -or $size.Height -ne 700 -or $size.MinWidth -ne 960 -or $size.MinHeight -ne 640){throw 'Incorrect initial window size'}
    Save-DeliveryWindowSize $path 1198 762
    $size=Get-DeliveryWindowSize $path 1920 1040
    if($size.Width -ne 1198 -or $size.Height -ne 762){throw 'Saved size did not round trip'}
    $small=Get-DeliveryWindowSize $path 910 512
    if($small.Width -ne 910 -or $small.Height -ne 512 -or $small.MinWidth -ne 910 -or $small.MinHeight -ne 512){throw 'Size did not fit a smaller work area'}
    [IO.File]::WriteAllText($path,'{ invalid json')
    $size=Get-DeliveryWindowSize $path 1920 1040
    if($size.Width -ne 1040 -or $size.Height -ne 700){throw 'Invalid settings should restore defaults'}
    [IO.File]::WriteAllText($path,'{"Width":-1,"Height":100}')
    $size=Get-DeliveryWindowSize $path 1920 1040
    if($size.Width -ne 1040 -or $size.Height -ne 700){throw 'Invalid dimensions should restore defaults'}
    . (Join-Path (Split-Path $PSScriptRoot) 'App.ps1') -NoShow
    $script:windowSettingsPath=$path
    $window.ShowActivated=$false;$window.Opacity=0
    $window.Show();$window.Width=1000;$window.Height=660
    $window.UpdateLayout()
    $expectedWidth=$script:normalWindowWidth;$expectedHeight=$script:normalWindowHeight
    $window.WindowState=[Windows.WindowState]::Maximized;$window.UpdateLayout()
    $window.Close()
    $saved=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if([Math]::Abs($saved.Width-$expectedWidth) -gt 1 -or [Math]::Abs($saved.Height-$expectedHeight) -gt 1){throw 'Closing did not save the normal size'}
    Write-Host 'Window settings tests passed: defaults, persistence, invalid data and small work area.'
} finally {
    if(Test-Path -LiteralPath $dir){Remove-Item -LiteralPath $dir -Recurse -Force}
}
