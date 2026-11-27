# reload-and-ping.ps1 — Ctrl-D でリロードして PING 確認
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
    param([int]$Ms = 1200)
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

Drain -Ms 700
$sp.Write([char]4)      # Ctrl-D = soft reload
Drain -Ms 1500
$sp.Write("PING`r")
Drain -Ms 1200
$sp.Write("ID?`r")
Drain -Ms 1200

$sp.Close()
Write-Output "=== reload-and-ping done ==="
