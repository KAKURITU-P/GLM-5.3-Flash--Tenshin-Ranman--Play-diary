# pico-mouse.ps1 — Pico W HID マウス操縦スクリプト(自己補正版)
# 使い方:
#   ping / where / reset / setfactor
#   move   -X <px> -Y <px> [-Resync]
#   click  -X <px> -Y <px> [-Resync]
#   dc     -X <px> -Y <px> [-Resync]
#   rclick -X <px> -Y <px> [-Resync]
#   wheel  -Y <steps>
# 位置は毎操作後に GetCursorPos で読み戻して自己補正する。
# factor = 1カウントあたりのピクセル数(既定 0.5 = 感度スライダー 6 の環境)
param(
    [Parameter(Position = 0)][string]$Cmd = "ping",
    [int]$X = 0,
    [int]$Y = 0,
    [string]$Port = "COM6",
    [double]$Factor = -1,
    [switch]$Resync
)
$ErrorActionPreference = "Stop"

$stateFile = Join-Path $PSScriptRoot "pico-mouse-state.json"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class PicoP {
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT pt);
  public struct POINT { public int X; public int Y; }
  public static string Pos() {
    POINT p; GetCursorPos(out p); return p.X + "," + p.Y;
  }
}
'@

function Get-RealPos {
    $parts = [PicoP]::Pos().Split(",")
    return @{ x = [int]$parts[0]; y = [int]$parts[1] }
}

function Send-Line {
    param([System.IO.Ports.SerialPort]$Sp, [string]$Line)
    $Sp.DiscardInBuffer()
    $Sp.WriteLine($Line)
    $deadline = (Get-Date).AddSeconds(4)
    $acc = ""
    while ((Get-Date) -lt $deadline) {
        $acc += $Sp.ReadExisting()
        if ($acc -match "(OK\r|OK\n|PONG|PICO-MOUSE|ERR)") { break }
        Start-Sleep -Milliseconds 15
    }
    return $acc.Trim()
}

function Wait-Ready {
    param([System.IO.Ports.SerialPort]$Sp)
    for ($i = 0; $i -lt 3; $i++) {
        $Sp.DiscardInBuffer()
        $Sp.WriteLine("PING")
        Start-Sleep -Milliseconds 350
        $r = $Sp.ReadExisting()
        if ($r -match "PONG") { return $true }
    }
    $Sp.Write([char]3)
    Start-Sleep -Milliseconds 200
    $Sp.Write("`r")
    Start-Sleep -Milliseconds 300
    $Sp.DiscardInBuffer()
    $Sp.WriteLine("exec(open('code.py').read())")
    Start-Sleep -Milliseconds 2000
    for ($i = 0; $i -lt 3; $i++) {
        $Sp.DiscardInBuffer()
        $Sp.WriteLine("PING")
        Start-Sleep -Milliseconds 350
        $r = $Sp.ReadExisting()
        if ($r -match "PONG") { return $true }
    }
    return $false
}

function Load-State {
    if (Test-Path $stateFile) {
        try {
            $j = Get-Content $stateFile -Raw | ConvertFrom-Json
            $f = 0.5; if ($j.factor) { $f = [double]$j.factor }
            return @{ x = [int]$j.x; y = [int]$j.y; synced = [int]$j.synced; factor = $f }
        } catch { }
    }
    return @{ x = -1; y = -1; synced = 0; factor = 0.5 }
}

function Save-State {
    param($s)
    @{ x = $s.x; y = $s.y; synced = $s.synced; factor = $s.factor } | ConvertTo-Json |
        Set-Content -Path $stateFile -Encoding ASCII
}

function Move-ToPx {
    param([System.IO.Ports.SerialPort]$Sp, $s, [int]$tx, [int]$ty)
    $dxPx = [double]($tx - $s.x)
    $dyPx = [double]($ty - $s.y)
    $dxc = [int][math]::Round($dxPx / $s.factor)
    $dyc = [int][math]::Round($dyPx / $s.factor)
    if ($dxc -ne 0 -or $dyc -ne 0) {
        [void](Send-Line $sp ("M {0} {1}" -f $dxc, $dyc))
    }
    Start-Sleep -Milliseconds 80
    $real = Get-RealPos
    $s.x = $real.x; $s.y = $real.y
    return $s
}

function Resync {
    param([System.IO.Ports.SerialPort]$Sp, $s)
    [void](Send-Line $sp "M -24000 -24000")
    Start-Sleep -Milliseconds 120
    $real = Get-RealPos
    $s.x = $real.x; $s.y = $real.y; $s.synced = 1
    return $s
}

# ---- メイン ----
$sp = New-Object System.IO.Ports.SerialPort($Port, 115200)
$sp.DtrEnable = $true
$sp.RtsEnable = $true
$sp.Open()
Start-Sleep -Milliseconds 200
if (-not (Wait-Ready $sp)) { $sp.Close(); throw "Pico-mouse no response (PING failed)" }

try {
    $s = Load-State
    if ($Factor -gt 0) { $s.factor = $Factor; Save-State $s }

    switch ($Cmd.ToLower()) {
        "ping"      { Write-Output "pong ok (port=$Port)" }
        "where"     { Write-Output ("state pos=({0},{1}) factor={2} synced={3} real={4}" -f $s.x, $s.y, $s.factor, $s.synced, [PicoP]::Pos()) }
        "reset"     { if (Test-Path $stateFile) { Remove-Item $stateFile -Force }; Write-Output "state cleared" }
        "setfactor" { $s.factor = $Factor; Save-State $s; Write-Output ("factor=" + $s.factor) }
        "move" {
            if ($Resync -or $s.synced -eq 0 -or $s.x -lt 0) { $s = Resync $sp $s }
            $s = Move-ToPx $sp $s $X $Y
            Save-State $s
            Write-Output ("move -> target({0},{1}) real({2},{3})" -f $X, $Y, $s.x, $s.y)
        }
        "click" {
            if ($Resync -or $s.synced -eq 0 -or $s.x -lt 0) { $s = Resync $sp $s }
            $s = Move-ToPx $sp $s $X $Y
            Start-Sleep -Milliseconds 40
            [void](Send-Line $sp "C")
            Start-Sleep -Milliseconds 60
            $real = Get-RealPos
            $s.x = $real.x; $s.y = $real.y
            Save-State $s
            Write-Output ("click -> target({0},{1}) real({2},{3})" -f $X, $Y, $s.x, $s.y)
        }
        "dc" {
            if ($Resync -or $s.synced -eq 0 -or $s.x -lt 0) { $s = Resync $sp $s }
            $s = Move-ToPx $sp $s $X $Y
            Start-Sleep -Milliseconds 40
            [void](Send-Line $sp "DC")
            Start-Sleep -Milliseconds 80
            $real = Get-RealPos
            $s.x = $real.x; $s.y = $real.y
            Save-State $s
            Write-Output ("dc -> target({0},{1}) real({2},{3})" -f $X, $Y, $s.x, $s.y)
        }
        "rclick" {
            if ($Resync -or $s.synced -eq 0 -or $s.x -lt 0) { $s = Resync $sp $s }
            $s = Move-ToPx $sp $s $X $Y
            Start-Sleep -Milliseconds 40
            [void](Send-Line $sp "R")
            Start-Sleep -Milliseconds 60
            $real = Get-RealPos
            $s.x = $real.x; $s.y = $real.y
            Save-State $s
            Write-Output ("rclick -> target({0},{1}) real({2},{3})" -f $X, $Y, $s.x, $s.y)
        }
        "wheel" {
            [void](Send-Line $sp ("W {0}" -f $Y))
            Write-Output ("wheel {0}" -f $Y)
        }
        default { throw "unknown cmd: $Cmd" }
    }
} finally {
    $sp.Close()
}
