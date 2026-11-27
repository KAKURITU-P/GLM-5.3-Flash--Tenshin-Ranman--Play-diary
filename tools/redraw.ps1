# redraw.ps1 — KiriKiri の再描画(Present)停止を解除する暫定対応
# 手順: タイトルバーをダブルクリックして 最大化 → 復元 のトグルを行う。
# サイズ変更イベントでゲームの描画が再開し、溜まっていた進行が画面に反映される。
# 初期状態が「ウィンドウ」「最大化」どちらでも、2回の dc で元に戻る。
# 使い方:
#   引き渡し直後(HP 画面を消す猶予が必要): -File redraw.ps1            (既定 10秒待つ)
#   停滞復活時(消灯は済んでいる):            -File redraw.ps1 -WaitSec 0
param([int]$WaitSec = 10)
$ErrorActionPreference = "Stop"
$tools = $PSScriptRoot
$pico = Join-Path $tools "pico-mouse.ps1"
$fs   = Join-Path $tools "fullscreen.ps1"

# 0) 開始前待ち: 引き渡し直後はユーザーが HP 画面の電源を消す猶予(既定 10秒)
if ($WaitSec -gt 0) {
    Write-Output ("waiting " + $WaitSec + "s for monitor power-off...")
    Start-Sleep -Seconds $WaitSec
}

# 1) タイトルバーのダブルクリック(トグル 1回目: 最大化)
#    -Resync 付きでカーソル位置の自己補正も行う
powershell -NoProfile -ExecutionPolicy Bypass -File $pico dc -X 1100 -Y 172 -Resync
Start-Sleep -Milliseconds 1200

# 2) 最大化中のタイトルバーは画面最上部 → 空きスペース(タイトル文字を避ける)をダブルクリック(トグル 2回目: 復元)
powershell -NoProfile -ExecutionPolicy Bypass -File $pico dc -X 1600 -Y 12
Start-Sleep -Milliseconds 800

# 3) スクショ 1枚で復元後の bounds・描画状態を確認できるようにする
powershell -NoProfile -ExecutionPolicy Bypass -File $fs
