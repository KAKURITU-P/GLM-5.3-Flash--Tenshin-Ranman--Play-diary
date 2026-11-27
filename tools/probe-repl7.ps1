# probe-repl7.ps1 — Ctrl-C で中断→ exec で code.py 実行 → PING
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
$sp.Write([char]3)      # Ctrl-C: 未終了ブロック/実行中断
Start-Sleep -Milliseconds 200
$sp.Write("`r")         # 空行で確実にプロンプトへ
Drain -Ms 800

$sp.Write("exec(open('code.py').read())`r")
Drain -Ms 3500

$sp.Write("PING`r")
Drain -Ms 1500

$sp.Close()
Write-Output "=== probe7 done ==="
