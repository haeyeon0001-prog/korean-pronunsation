# Whisper Proxy Worker — デプロイ手順

学生に OpenAI キーを貼らせなくて済むようにするためのサーバレスプロキシ。
先生のキーだけ Worker の Secret に入れておく → アプリは Worker 経由で Whisper を叩く。

## 1 回きりのセットアップ

### オプション A: CLI (wrangler)

```bash
# 1. Cloudflare アカウント作成 (無料)  https://dash.cloudflare.com/sign-up
# 2. wrangler インストール
npm install -g wrangler

# 3. ログイン
wrangler login

# 4. このフォルダから Secret を登録
cd cloudflare-worker
wrangler secret put OPENAI_API_KEY
# プロンプトで sk-... を貼り付け → Enter

# 5. デプロイ
wrangler deploy
# → 出力に https://korean-pron-whisper.<your-subdomain>.workers.dev が表示される
```

### オプション B: ダッシュボード GUI

1. https://dash.cloudflare.com/ → Workers & Pages → **Create**
2. **Create Worker** → 名前: `korean-pron-whisper` → Deploy
3. 右上 **Edit code** → `worker.js` の中身をまるごと貼り付けて **Deploy**
4. Worker のページ → **Settings** → **Variables and Secrets** → **Add**
   - Type: **Secret**, Name: `OPENAI_API_KEY`, Value: `sk-...`
5. URL をコピー (例: `https://korean-pron-whisper.yourname.workers.dev`)

## アプリ側の設定

`docs/index.html` 冒頭の `WHISPER_PROXY_URL` に上記 URL を貼る:

```js
const WHISPER_PROXY_URL = 'https://korean-pron-whisper.yourname.workers.dev';
```

push → GitHub Pages で反映。以後、学生はキーを設定しなくても 🎙️ が動きます。

## コスト

- Workers 無料枠: **100,000 リクエスト/日**。1 クラスで使う分には絶対に超えない
- Whisper 側は先生の OpenAI 課金。$0.006/分 — 10 秒の発音 × 30 人 × 30 単語 = 150 分/日 ≒ $0.90

## セキュリティのもう一段

動き出したら `wrangler.toml` の `ALLOWED_ORIGIN` を GitHub Pages URL に絞るのがおすすめ
(他サイトからの無断利用を防げる)。
