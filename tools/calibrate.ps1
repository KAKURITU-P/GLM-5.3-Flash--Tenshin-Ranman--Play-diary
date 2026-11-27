# calibrate.ps1 — Pico マウスの実ピクセル換算を測定
param([string]$Port = "COM6")
if (-not $Port) { $Port = "COM6" }
$ErrorActionPreference = "Stop"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class CP {
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT pt);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  public struct POINT { public int X; public int Y; }
}
'@

$pt = New-Object CP+POINT
# 基準: OS 側でカーソルを (100,100) に置き、そこを「Pico の現在位置」とする
[CP]::SetCursorPos(100, 100) | Out-Null
Start-Sleep -Milliseconds 150
[CP]::GetCursorPos([ref]$pt) | Out-Null
Write-Output ("start cursor: " + $pt.X + "," + $pt.Y)
$state = @{ x = $pt.X; y = $pt.Y; synced = 1 }
$state | ConvertTo-Json | Set-Content -Path (Join-Path $PSScriptRoot "pico-mouse-state.json") -Encoding ASCII

# Pico で +500,+300 移動
Write-Output ("port param: [" + $Port + "]")
try {
    $sp = New-Object System.IO.Ports.SerialPort -ArgumentList $Port, 115200
    Write-Output ("sp type: " + $sp.GetType().FullName)
} catch {
    Write-Output ("ctor failed: " + $_)
    throw
}
$sp.ReadTimeout = 500
$sp.DtrEnable = $true
$sp.RtsEnable = $true
$sp.Open()
Start-Sleep -Milliseconds 200
$sp.DiscardInBuffer()
$sp.WriteLine("M 500 300")
Start-Sleep -Milliseconds 700
$sp.DiscardInBuffer()
$sp.Close()

[CP]::GetCursorPos([ref]$pt) | Out-Null
Write-Output ("after M 500 300 -> cursor: " + $pt.X + "," + $pt.Y)

$dx = $pt.X - 100
$dy = $pt.Y - 100
Write-Output ("delta: " + $dx + "," + $dy)
if ($dx -ne 0) { Write-Output ("factorX = " + [math]::Round($dx / 500, 4)) }
if ($dy -ne 0) { Write-Output ("factorY = " + [math]::Round($dy / 300, 4)) }
