# check-pointer.ps1 — ポインター加速設定の確認
Write-Output "=== Mouse registry (HKCU\Control Panel\Mouse) ==="
$m = Get-ItemProperty 'HKCU:\Control Panel\Mouse'
Write-Output ("MouseSpeed (0=加速OFF): " + $m.MouseSpeed)
Write-Output ("MouseSensitivity (10=標準1:1): " + $m.MouseSensitivity)
Write-Output ("MouseThreshold1: " + $m.MouseThreshold1)
Write-Output ("MouseThreshold2: " + $m.MouseThreshold2)

Write-Output "=== Screen info ==="
Add-Type -AssemblyName System.Windows.Forms
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
Write-Output ("Primary: " + $b.Width + " x " + $b.Height)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class P {
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT pt);
  public struct POINT { public int X; public int Y; }
}
'@
$pt = New-Object P+POINT
[P]::GetCursorPos([ref]$pt) | Out-Null
Write-Output ("Cursor now: " + $pt.X + "," + $pt.Y)
