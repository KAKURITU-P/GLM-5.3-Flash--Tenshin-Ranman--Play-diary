# COM ポートの全列挙と CIRCUITPY ドライブの中身確認
Write-Output "=== All COM ports ==="
[System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { Write-Output $_ }

Write-Output "=== PnP Serial/COM entities ==="
Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match "COM\d|Serial|Pico|RP2" } | ForEach-Object {
    Write-Output ($_.Name + "  |  " + $_.DeviceID)
}

Write-Output "=== CIRCUITPY contents ==="
Get-ChildItem F:\ | ForEach-Object { Write-Output $_.Name }
if (Test-Path F:\lib\adafruit_hid) {
    Write-Output "--- lib/adafruit_hid found ---"
    Get-ChildItem F:\lib\adafruit_hid | ForEach-Object { Write-Output $_.Name }
} else {
    Write-Output "--- lib/adafruit_hid NOT found ---"
}
