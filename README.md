# 韓国語発音練習 PWA

公開先: https://haeyeon0001-prog.github.io/korean-pronunsation/

GitHub Pages が `main` ブランチの `docs/` を自動でデプロイします。

## ディレクトリ構成

```
korean-pronunciation/
├── docs/                        ← GitHub Pages 配信ルート
│   ├── index.html               ← アプリ本体 (単一ファイル PWA)
│   └── audio/
│       ├── manifest.json        ← 単語 → m4a ファイル名のマッピング
│       └── <md5>.m4a            ← 事前録音音声 (Jian Premium)
├── gen-audio.sh                 ← 音声生成スクリプト (macOS Jian Premium)
├── cloudflare-worker/           ← Whisper 評価用プロキシ (オプション)
└── README.md                    ← このファイル
```

## 音声仕様

- 音声: macOS `Jian (Premium)` (韓国語ネイティブ・女性)
- 速度: `-r 160`
- フォーマット: AAC m4a / 22050Hz / mono / 64kbps
- 末尾ピリオド付加で途中切れ防止

全公開音声がこの仕様で統一されています。

## 単語の追加 / 更新手順

```bash
# 1. gen-audio.sh の TEXTS=( ... ) に追加
vim gen-audio.sh

# 2. 音声生成 (既存ファイルは触らない・冪等)
bash gen-audio.sh

# 3. docs/index.html で UI に追加
#    - PRACTICE_GYEOK / PRACTICE_NONG / PRACTICE_PYEONG など対応する配列に追記
#    - 上部の AUDIO_VERSION を更新 (キャッシュバスター)

# 4. コミット & プッシュ
git add docs/audio/*.m4a docs/audio/manifest.json docs/index.html
git commit -m "Add ..."
git push origin main
```

数分で GitHub Pages が自動デプロイします。

## Jian Premium のインストール (新しいMacで作業する場合)

```
システム設定 → アクセシビリティ → 読み上げコンテンツ
  → システムの声 → 韓国語 → Jian (Premium) をダウンロード
```

確認:
```bash
say -v 'Jian (Premium)' "안녕하세요"
```

音が鳴れば準備完了。

## ローカルプレビュー

```bash
cd docs && python3 -m http.server 8000
# http://localhost:8000 を開く
```
