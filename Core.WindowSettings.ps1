Set-StrictMode -Version Latest

function Get-DeliveryWindowSize {
    param([string]$Path,[double]$WorkWidth,[double]$WorkHeight)
    if([double]::IsNaN($WorkWidth) -or [double]::IsInfinity($WorkWidth) -or $WorkWidth -le 0){$WorkWidth=1040}
    if([double]::IsNaN($WorkHeight) -or [double]::IsInfinity($WorkHeight) -or $WorkHeight -le 0){$WorkHeight=700}
    $minWidth=[Math]::Min(960,$WorkWidth);$minHeight=[Math]::Min(640,$WorkHeight)
    $width=1040.0;$height=700.0
    try {
        if(Test-Path -LiteralPath $Path -PathType Leaf){
            $saved=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            $w=[double]$saved.Width;$h=[double]$saved.Height
            if(-not [double]::IsNaN($w) -and -not [double]::IsInfinity($w) -and -not [double]::IsNaN($h) -and -not [double]::IsInfinity($h) -and $w -gt 0 -and $h -gt 0){$width=$w;$height=$h}
        }
    } catch { }
    return [pscustomobject]@{Width=[Math]::Max($minWidth,[Math]::Min($width,$WorkWidth));Height=[Math]::Max($minHeight,[Math]::Min($height,$WorkHeight));MinWidth=$minWidth;MinHeight=$minHeight}
}

function Save-DeliveryWindowSize {
    param([string]$Path,[double]$Width,[double]$Height)
    if([double]::IsNaN($Width) -or [double]::IsInfinity($Width) -or [double]::IsNaN($Height) -or [double]::IsInfinity($Height) -or $Width -le 0 -or $Height -le 0){return}
    $directory=Split-Path -Parent $Path
    if(-not (Test-Path -LiteralPath $directory -PathType Container)){[void](New-Item -ItemType Directory -Path $directory -Force)}
    @{Width=[Math]::Round($Width,2);Height=[Math]::Round($Height,2)} | ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop
}
