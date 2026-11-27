# probe-repl4.ps1 — Mouse API の実態調査
param([string]$Port = "COM6")
Write-Output ("param Port = [" + $Port + "]")
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

$sp.Write("from adafruit_hid.mouse import Mouse`r")
Drain -Ms 1000
$sp.Write("print('TYPE', type(Mouse))`r")
Drain -Ms 800
$sp.Write("print('DOC', repr(Mouse.__doc__)[:120])`r")
Drain -Ms 800
$sp.Write("print('MODDOC', repr(__import__('adafruit_hid.mouse').__doc__)[:200])`r")
Drain -Ms 800
$sp.Write("import usb_hid; print('HIDEN', usb_hid.enabled)`r")
Drain -Ms 800
$sp.Write("print('DEVS', usb_hid.devices)`r")
Drain -Ms 800
$sp.Write("print('DIR', [n for n in dir(Mouse) if not n.startswith('__')])`r")
Drain -Ms 800

$sp.Close()
Write-Output "=== probe4 done ==="
