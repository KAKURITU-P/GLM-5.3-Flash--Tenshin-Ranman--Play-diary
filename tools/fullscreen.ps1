# fullscreen.ps1 — 画面全体のスクリーンショットを保存
param([string]$OutPath = "")
$ErrorActionPreference = "Stop"
if (-not $OutPath) {
    $OutPath = Join-Path $PSScriptRoot ("screen-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".png")
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("saved: " + $OutPath + " (" + $b.Width + "x" + $b.Height + ")")
