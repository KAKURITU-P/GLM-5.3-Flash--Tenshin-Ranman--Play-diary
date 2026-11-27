# Pico (CIRCUITPYTHON ドライブ / COM ポート) を検出する
$ErrorActionPreference = "SilentlyContinue"

Write-Output "=== CIRCUITPY Drive ==="
Get-Volume | Where-Object { $_.FileSystemLabel -like "*CIRCUIT*" } | ForEach-Object {
    Write-Output ("DriveLetter: " + $_.DriveLetter + "  Label: " + $_.FileSystemLabel + "  FreeKB: " + $_.SizeRemaining)
}

Write-Output "=== COM Ports (CircuitPython candidates) ==="
Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match "CircuitPython|USB Serial Device" } | ForEach-Object {
    Write-Output $_.Name
}
