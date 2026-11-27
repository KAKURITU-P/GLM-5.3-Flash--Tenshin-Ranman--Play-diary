# probe-repl3.ps1 — code.py を手動実行してトレースバックを取得
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

Drain -Ms 800
$sp.Write([char]3)
Start-Sleep -Milliseconds 100
$sp.Write("`r")
Drain -Ms 500

$sp.Write("from adafruit_hid.mouse import Mouse`r")
Drain -Ms 1200
$sp.Write("mo = Mouse(); print('mouse ctor ok')`r")
Drain -Ms 1200
$sp.Write("exec(open('code.py').read())`r")
Drain -Ms 2500

# code.py が生きているなら PING に応答するはず
$sp.Write("PING`r")
Drain -Ms 1200

$sp.Close()
Write-Output "=== probe3 done ==="
