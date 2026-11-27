# set-mouse-1to1.ps1 — マウス加速を無効化し 1カウント=1px にする(元に戻す用の値も記録)
$ErrorActionPreference = "Stop"

# 現在値を退避
$m = Get-ItemProperty 'HKCU:\Control Panel\Mouse'
$backup = @{
    MouseSpeed       = $m.MouseSpeed
    MouseSensitivity = $m.MouseSensitivity
    MouseThreshold1  = $m.MouseThreshold1
    MouseThreshold2  = $m.MouseThreshold2
}
$backup | ConvertTo-Json | Set-Content -Path (Join-Path $PSScriptRoot "mouse-backup.json") -Encoding UTF8
Write-Output ("backup saved: " + (ConvertTo-Json $backup -Compress))

# レジストリ変更(永続)
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseSpeed -Value "0"
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseSensitivity -Value "10"
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseThreshold1 -Value "0"
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseThreshold2 -Value "0"

# ライブ適用 (SystemParametersInfo)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class SPI {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref uint pvParam, uint fWinIni);
}
'@

# SPI_SETMOUSE (0x0004) = 加速しきい値 {0,0,0}
$ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(12)
[void][System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, 0, 0)
[void][System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, 4, 0)
[void][System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, 8, 0)
$ok1 = [SPI]::SystemParametersInfo(0x0004, 0, $ptr, 0x03)
[System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)

# SPI_SETMOUSESPEED (0x0071) = 10 (1:1)
$speed = [UInt32]10
$ok2 = [SPI]::SystemParametersInfo(0x0071, 0, [ref]$speed, 0x03)

Write-Output ("SPI_SETMOUSE ok=" + $ok1 + "  SPI_SETMOUSESPEED ok=" + $ok2)

# 確認
$m2 = Get-ItemProperty 'HKCU:\Control Panel\Mouse'
Write-Output ("now: Speed=" + $m2.MouseSpeed + " Sens=" + $m2.MouseSensitivity + " T1=" + $m2.MouseThreshold1 + " T2=" + $m2.MouseThreshold2)
