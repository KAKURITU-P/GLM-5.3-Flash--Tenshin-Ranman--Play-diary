# fullscreen-cursor.ps1 — カーソル付き全画面スクショ
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class CurInfo {
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT pt);
  [DllImport("user32.dll")] public static extern bool GetIconInfo(IntPtr hIcon, out ICONINFO piconinfo);
  [DllImport("user32.dll")] public static extern IntPtr CopyIcon(IntPtr hIcon);
  [DllImport("user32.dll")] public static extern IntPtr GetCursor();
  public struct POINT { public int X; public int Y; }
  public struct ICONINFO { public bool fIcon; public int xHotspot; public int yHotspot; public IntPtr hbmMask; public IntPtr hbmColor; }
}
'@

$outPath = Join-Path $PSScriptRoot ("cursor-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".png")

$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)

# カーソルを取得して合成
$pt = New-Object CurInfo+POINT
[CurInfo]::GetCursorPos([ref]$pt) | Out-Null
$hIcon = [CurInfo]::GetCursor()
if ($hIcon -ne [IntPtr]::Zero) {
    $ii = New-Object CurInfo+ICONINFO
    [CurInfo]::GetIconInfo($hIcon, [ref]$ii) | Out-Null
    try {
        $cursorBmp = [System.Drawing.Bitmap]::FromHicon($hIcon)
        $g.DrawImage($cursorBmp, $pt.X - $ii.xHotspot, $pt.Y - $ii.yHotspot)
        $cursorBmp.Dispose()
    } catch {
        # フォールバック:矢印マークを描く
        $g.DrawEllipse([System.Drawing.Pens]::Red, $pt.X - 8, $pt.Y - 8, 16, 16)
        $g.DrawLine([System.Drawing.Pens]::Red, $pt.X - 12, $pt.Y, $pt.X + 12, $pt.Y)
        $g.DrawLine([System.Drawing.Pens]::Red, $pt.X, $pt.Y - 12, $pt.X, $pt.Y + 12)
    }
    if ($ii.hbmMask -ne [IntPtr]::Zero) { }
    if ($ii.hbmColor -ne [IntPtr]::Zero) { }
} else {
    $g.DrawEllipse([System.Drawing.Pens]::Red, $pt.X - 8, $pt.Y - 8, 16, 16)
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GDI2 { [DllImport("user32.dll")] public static extern bool DeleteObject(IntPtr o); }
'@ -ErrorAction SilentlyContinue

$g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("saved: " + $outPath + "  cursor=(" + $pt.X + "," + $pt.Y + ")")
