# probe-repl.ps1 — Pico の REPL 状態を診断する
param([string]$Port = "COM6")
$ErrorActionPreference = "Stop"

$sp = New-Object System.IO.Ports.SerialPort($Port, 115200)
$sp.ReadTimeout = 300
$sp.DtrEnable = $true
$sp.RtsEnable = $true
$sp.Open()
Start-Sleep -Milliseconds 300

function Read-All {
    param([int]$Ms = 600)
    Start-Sleep -Milliseconds $Ms
    $t = $sp.ReadExisting()
    Write-Output ("<< " + ($t -replace "`r", "" -replace "`n", "\n"))
}

# 現在のバッファ内容を吐き出す
Read-All -Ms 800

# Ctrl-C を送って REPL を確定させる
$sp.Write([char]3)
Read-All -Ms 400

# 属性チェック
$sp.WriteLine("import supervisor")
Read-All -Ms 400
$sp.WriteLine("print('A1', hasattr(supervisor.runtime,'serial_bytes_available'))")
Read-All -Ms 500
$sp.WriteLine("print('A2', hasattr(supervisor.runtime,'serial_available'))")
Read-All -Ms 500
$sp.WriteLine("import usb_cdc; print('CDC', usb_cdc.console, usb_cdc.data)")
Read-All -Ms 500
$sp.WriteLine("import usb_hid; print('HID', usb_hid.enabled, [d for d in usb_hid.devices])")
Read-All -Ms 500

$sp.Close()
Write-Output "=== probe done ==="
