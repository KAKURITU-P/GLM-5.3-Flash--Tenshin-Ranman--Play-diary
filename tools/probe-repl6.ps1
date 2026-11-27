# probe-repl6.ps1 — code.py を手動実行(修正版)+ 状態診断
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

Drain -Ms 800
$sp.Write([char]3)      # Ctrl-C
Start-Sleep -Milliseconds 150
$sp.Write("`r")
Drain -Ms 600

$sp.Write("print('AR', supervisor.runtime.autoreload)`r")
Drain -Ms 1000
$sp.Write("try:`r  print('RR', supervisor.runtime.run_reason)`rexcept Exception as e:`r  print('RRERR', e)`r")
Drain -Ms 1200

$sp.Write("exec(open('code.py').read())`r")
Drain -Ms 3000

$sp.Write("PING`r")
Drain -Ms 1200

$sp.Close()
Write-Output "=== probe6 done ==="
