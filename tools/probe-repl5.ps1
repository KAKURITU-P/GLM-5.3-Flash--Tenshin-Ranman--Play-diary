# probe-repl5.ps1 — Mouse コンストラクタの正しい呼び方を探る
param([string]$Port = "COM6")
if (-not $Port) { $Port = "COM6" }
$ErrorActionPreference = "Stop"

$sp = New-Object System.IO.Ports.SerialPort($Port, 115200)
$sp.ReadTimeout = 100
$sp.DtrEnable = $true
$sp.RtsEnable = $true
$sp.Open()
Start-Sleep -Milliseconds 300

function Drain {
    param([int]$Ms = 1500)
    $deadline = (Get-Date).AddMilliseconds($Ms)
    $acc = ""
    while ((Get-Date) -lt $deadline) {
        try {
            $t = $sp.ReadExisting()
            if ($t) { $acc += $t }
        } catch {}
        Start-Sleep -Milliseconds 40
    }
    Write-Output ("<< " + ($acc -replace "`r", "" -replace "`x1b", "<ESC>"))
}

Drain -Ms 600
$sp.Write([char]3)
Start-Sleep -Milliseconds 100
$sp.Write("`r")
Drain -Ms 400

$sp.Write("from adafruit_hid.mouse import Mouse; import usb_hid`r")
Drain -Ms 1000
$sp.Write("print('N', len(usb_hid.devices))`r")
Drain -Ms 800
$sp.Write("print([d.get_report_description()[:60] for d in usb_hid.devices])`r")
Drain -Ms 1000
$sp.Write("m = Mouse(usb_hid.devices); print('CTOR-1 ok')`r")
Drain -Ms 1000
$sp.Write("print('MOVE', m.move(3, 0), 'moved')`r")
Drain -Ms 800

$sp.Close()
Write-Output "=== probe5 done ==="
