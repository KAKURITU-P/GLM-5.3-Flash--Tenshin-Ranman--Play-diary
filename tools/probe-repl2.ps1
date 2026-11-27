# probe-repl2.ps1 — 結果が見えるまで読み続ける版
param([string]$Port = "COM6")
$ErrorActionPreference = "Stop"

$sp = New-Object System.IO.Ports.SerialPort($Port, 115200)
$sp.ReadTimeout = 100
$sp.DtrEnable = $true
$sp.RtsEnable = $true
$sp.NewLine = "`r"
$sp.Open()
Start-Sleep -Milliseconds 300

function Drain {
    param([int]$Ms = 2000)
    $deadline = (Get-Date).AddMilliseconds($Ms)
    $acc = ""
    while ((Get-Date) -lt $deadline) {
        try {
            $t = $sp.ReadExisting()
            if ($t) { $acc += $t }
        } catch {}
        Start-Sleep -Milliseconds 50
    }
    Write-Output ("<< " + ($acc -replace "`r", "" -replace "`x1b", "<ESC>"))
}

Drain -Ms 1000
$sp.Write([char]3)
Start-Sleep -Milliseconds 100
$sp.Write("`r")
Drain -Ms 800

$sp.Write("import supervisor`r")
Drain -Ms 1200
$sp.Write("print('A1', hasattr(supervisor.runtime,'serial_bytes_available'))`r")
Drain -Ms 1200
$sp.Write("print('A2', hasattr(supervisor.runtime,'serial_available'))`r")
Drain -Ms 1200
$sp.Write("print('CODE test', 6*7)`r")
Drain -Ms 1200

$sp.Close()
Write-Output "=== probe2 done ==="
