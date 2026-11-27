# 天神乱漫 自律プレイ 操作マニュアル

> GLM-5.3-Flash(GLMたん)の運用ノウハウまとめ。セーブデータを消した AI のための再起動用マニュアル。
> 前提: Pico W HID マウス + CUA 観察の 2 点構成。**このマニュアルの内容はすべて実機で検証済み**(失敗と対策込み)。

## 0. 環境

| 項目 | 値 |
|---|---|
| ゲーム | 天神乱漫 LUCKY or UNLUCKY!?(H:\YUZUSOFT\天神乱漫\tenshin.exe) |
| エンジン | KiriKiri(TTVPWindowForm) |
| OS | Windows 11 Insider Preview Build 26340.10032 |
| ディスプレイ | HP 222va(DP・実在)+ HDP-V104(HDMI ダミープラグ)、**複製モード 1920x1080** |
| Pico W | COM6、115200、CircuitPython、factor 1.0(マウス加速オフ・感度10の 1:1 環境) |

## 1. 観察方法

### CUA(第一選択)
- computer-use スキルをロードし、毎呼び出しブートストラップ(node_repl は呼び出し毎にワーカーがリセットされる):
  ```js
  const root = process.env.ZCODE_CUA_PLUGIN_ROOT ?? process.env.ZCODE_PLUGIN_ROOT ?? process.env.CLAUDE_PLUGIN_ROOT;
  const { join } = await import("node:path");
  const { pathToFileURL } = await import("node:url");
  const { setupComputerUseRuntime } = await import(pathToFileURL(join(root, "scripts", "computer-use-client.mjs")).href);
  await setupComputerUseRuntime({ globals: globalThis });
  const apps = await agent.computerUse.listApps({ emit: false });
  const app = await agent.computerUse.getApp({ name: "天神乱漫の起動" });  // pid は実行ごとに変わるので listApps で確認
  await app.getScreenshot({ emit: true });  // emit:true で画像表示
  ```
- window.bounds から画面座標を計算する(画面X = bounds.x + ラスターX)
- **CUA クリックは使わない**(下記 §2)

### GDI フォールバック
- CUA が不調(応答消失 2 回連続など)のとき:
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools\fullscreen.ps1` → 出力 PNG を Read で読む
- 応答消失エラーは「observe the target state first」と言われるので、自動リプレイではなく観察からやり直す

### 「Same call ×5」警告
- node_repl が同一パターンの反復を検知して出す**誤検知**(ページ送り観察は必然的に同一パターンになる)
- 呼び出しが実際に拒否されない限り無視して続行してよい(14 コマ連続で問題なしの実績あり)

## 2. テキスト送り(Pico W HID マウス)

- **KiriKiri は合成クリック(CUA クリック)を無視する**。テキスト送りは必ず Pico HID の実イベントを使う
- コマンド:
  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\pico-mouse.ps1 click -X <画面X> -Y <画面Y>
  ```
- **クリック位置はメッセージウィンドウ中央**を推奨(通常 bounds [737,157,1173,710] → (1137,749))
  - **右下固定(1300,820)は非推奨** — QSAVE/QLOAD/SYSTEM ボタンの近くで誤爆リスクがある
  - 1 クリック = 1 ページ。クリック → 1 秒待ち → 観察 → 読む、を 1 ページずつ
- 実位置がターゲットから **30px 以上ズレたら同じクリックを再試行**(スクリプト内蔵の自己補正がある)
- state ファイル(tools/pico-mouse-state.json)が古いと位置が飛ぶ → `calibrate.ps1` で factor 再実測 → `setfactor -Factor 1` → `-Resync` 付きクリックで解消
- Ping が通らない場合は pico-mouse.ps1 内蔵の Wait-Ready(PING リトライ → Ctrl-C → REPL ブートストラップ)が自動で復旧を試みる

## 3. 描画停止問題と redraw(最重要の学び)

- **モニター消灯時、KiriKiri は「再描画だけ」止まる** — ゲーム内部(VM・入力処理)は生きていて進行している。スクショが古いフレームのまま変わらないのはこれ
- 検知: クリックしてもテキストが 3 回変わらない → まず redraw を疑う(停滞=進行停止とは限らない)
- 対策: `tools\redraw.ps1` — タイトルバーをダブルクリックで 最大化→復元 のトグル。サイズ変更イベントで描画が再開し、溜まっていた進行が一気に見える
  - 引き渡し直後: `redraw.ps1`(既定で 10 秒待ってから実行 — HP 画面を消す猶予)
  - 停滞復活時: `redraw.ps1 -WaitSec 0`(消灯は済んでいるので即実行)
- 初期状態がウィンドウでも最大化でも、2 回の dc で元に戻るので汎用

## ツールリファレンス(スクリプト一覧と使い方)

すべて `tools/` フォルダ配下。呼び出し形式: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>`

### pico-mouse.ps1 — Pico W HID マウス操縦(テキスト送りの本体)

| コマンド | 引数 | 動作 |
|---|---|---|
| ping | なし | PING→PONG で生存確認 |
| where | なし | state の位置と実位置(OS カーソル)を表示 |
| reset | なし | state ファイルを削除(初期化) |
| setfactor | `-Factor <数値>` | state の factor を設定・保存 |
| move | `-X -Y [-Resync]` | 指定座標へ移動(クリックなし) |
| click | `-X -Y [-Resync]` | 移動+左クリック(**テキスト送りはこれ**) |
| dc | `-X -Y [-Resync]` | 移動+ダブルクリック(タイトルバーで最大化トグル等に使用) |
| rclick | `-X -Y [-Resync]` | 移動+右クリック |
| wheel | `-Y <steps>` | ホイールスクロール |

- 共通パラメータ: `-Port COM6`(既定)、`-Factor 1.0`
- 出力例: `click -> target(1137,749) real(1137,749)` — **real がターゲットと 30px 以上ズレたら同じクリックを再試行**
- `-Resync` 付きは画面端スラム(左上 0,0 へ強制移動 → 実位置取得)してから移動するので、state が古いときに使う
- state ファイル(tools/pico-mouse-state.json): `{x, y, synced, factor}`。calibrate 実行後は位置情報が古くなるので setfactor + Resync で整合させる
- Ping 不通時は内蔵 Wait-Ready が PING リトライ → Ctrl-C → REPL ブートストラップ(`exec(open('code.py').read())`)で自動復旧を試みる

### fullscreen.ps1 — GDI 全画面スクショ(CUA 代替)

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\fullscreen.ps1 [-OutPath <path>]
```

- `-OutPath` 省略時: `tools\screen-YYYYMMDD-HHmmss.png`
- 出力: `saved: <path> (1920x1080)` — 取得した PNG は Read ツールで読む
- **カーソルは GDI キャプチャに映らない**(カーソル位置確認の用途には使えない)
- モニター消灯時でも DWM 合成が生きていれば正常取得できる(ダミープラグ複製モード環境)
- モニター消灯後なのに取得画像が古いフレームのまま変化しない → 描画停止(§3 の redraw で復活)

### fullscreen-cursor.ps1 — カーソル合成付きスクショ(診断用)

- 取得画像にカーソル位置の赤十字を合成して保存。カーソルが想定位置にいるかの確認用(通常運用では不要)

### calibrate.ps1 — factor 実測

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\calibrate.ps1
```

- OS 側でカーソルを (100,100) に置き、Pico に M 500 300 を送信 → 実位置から factorX/Y を算出表示
- **注意**: state を書き換えるが位置情報は「(100,100) 起点で (600,400) にいる」状態になる → 実行後は `setfactor -Factor 1` で factor 再設定し、次のクリックは `-Resync` 付きで位置整合

### redraw.ps1 — 描画起こし(§3 参照)

- 引き渡し直後: `-File redraw.ps1`(既定 10 秒待ってから実行 — HP 画面を消す猶予)
- 停滞復活時: `-File redraw.ps1 -WaitSec 0`
- 内部動作: タイトルバー (1100,172) をダブルクリック → 最大化 → 最上部 (1600,12) をダブルクリック → 復元 → スクショ 1 枚保存

### set-mouse-1to1.ps1 — マウス加速オフ設定(環境構築時のみ)

- MouseSpeed=0 / Sensitivity=10 / Threshold=0 を設定し 1 カウント=1px にする(元設定は mouse-backup.json に退避)
- 一度設定すれば以後は不要。factor 実測の前提になる設定

## 4. セーブ/ロード

- **Q.SAVE/SAVE/LOAD は絶対に触らない** — セーブ/ロードはユーザー担当
- セーブデータ系列の分離(savedata フォルダ):
  - data8x 系列 = GLMたん(GLM-5.3-Flash)
  - data7x 系列 = Qwen3.6(ローカル LLM)
- 再開時は自分の系列の最新スロットから Q.LOAD してもらう(私からはロード操作をしない)

## 5. 日記の書き方(著作権配慮)

- **あらすじは要約が主、引用は従**。本編テキストの長文逐次引用はしない(シーンの会話をほぼ再現する形は NG)
- 引用してよいのは**印象的な短いフレーズ(20 文字以下のオチのキーワード等)**のみ
- 構成: 進行状況 / あらすじメモ(要約) / 感想 / 操作メモ / 次の目標
- ファイル名: `天神乱漫_プレイ日記N.md`(番号連続)。**ファイル操作は慎重に** — 過去に文字化けファイル名(「天神4E08漫_…」)を作って削除する事故が発生している(ls で確認してからコミット)
- README の日記一覧も必ず更新
- 日記の署名(自分のモデル名)を入れると複数 AI の日記が混在したときに区別できる

## 6. git 運用

- push: `git add <files> && git commit -m "..." && git push origin master`
- push 拒否(non-fast-forward)のとき: `git pull --rebase origin master` してから再 push
- 自分のブランチ運用の場合も基本同じ(ブランチ名に置き換えるだけ)
- ブランチの覗き方(ワークツリーを変更せずに):
  - `git branch -a`(一覧)/ `git log origin/<branch> --oneline`(履歴)/ `git show origin/<branch>:<file>`(ファイル内容)
- 並行運用するなら `git worktree`(ブランチごとに独立フォルダ)が安全。ワークツリー 1 つで 2 ゲームのブランチ切り替えは競合の元

## 7. 運用ルール(セッションごとにユーザーと合意して設定)

- 時刻制限(例: 23時、16:20 以降で停止)とトークン制限(総残量が初期 70% 未満で停止)のどちらかで終了
- 終了処理: 日記作成(新規ファイル・上書き禁止)→ README 更新 → git push → CronPauseSelf
- **セーブはしない**(ゲームは起動したまま維持、勝手に終了しない)
- ゲームを勝手に起動/終了しない。未起動なら「ゲーム未起動、次回実行で再確認」と報告して終了
- 停滞検知: 同じテキストが 3 実行連続で変化しない → まず redraw → 復活しなければ原因を報告して停止
- Pico が 2 実行連続で応答しない → エラー報告して停止

## 8. よくある事故と対策(実績)

| 事故 | 対策 |
|---|---|
| クリックしても進まない(画面が古いフレーム) | 描画停止。redraw.ps1 で復活。**ゲームは進行しているので慌てない** |
| クリック後の実位置が大きくズレる | state が古い。calibrate → setfactor → Resync 付き再クリック |
| フォーカスがゲームにない | HID クリック自体は届くので、1 回目はアクティブ化に消費される場合がある。2 回連続で変化なしなら redraw 疑い |
| CUA 応答消失 | 自動リプレイせず観察からやり直す。2 回連続なら GDI にフォールバック |
| 文字化けファイル名を作る | コミット前に `git status` / `ls` でファイル名を確認 |
| QSAVE ボタン誤爆 | クリック位置をメッセージ中央に固定(右下固定は危険) |

## 9. 進行の引き継ぎについて

- ストーリー進行は AI 間で引き継ぐより「自分の系列のセーブで自分の目で読む」のが基本(日記はあくまで記録)
- 先行 AI の日記で先の展開を知ってしまった場合、日記では「先行情報がある前提の注目ポイント」と明示する
- ルート選択(選択肢)の判断基準はユーザーと合意する(例: 物語の核心に近い選択、気になる展開への寄り道可)
