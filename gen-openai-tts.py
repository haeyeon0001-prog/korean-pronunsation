#!/usr/bin/env python3
"""OpenAI TTS (tts-1) で韓国語音声を一括生成。

- 入力: gen-audio.sh の TEXTS 配列 (自動パース)
- 出力: app/audio/<md5>.mp3, manifest.json
- キー: /tmp/key.txt (1行)
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "app", "audio")
MANIFEST = os.path.join(OUT_DIR, "manifest.json")
SRC_SH = os.path.join(ROOT, "gen-audio.sh")
KEY_FILE = "/tmp/key.txt"

MODEL = "tts-1"
VOICE = "nova"
SPEED = 0.9
FMT = "mp3"


def load_key():
    with open(KEY_FILE) as f:
        k = f.read().strip()
    if not k.startswith("sk-"):
        raise RuntimeError("invalid key")
    return k


def parse_texts():
    with open(SRC_SH, encoding="utf-8") as f:
        src = f.read()
    m = re.search(r"TEXTS=\(\n(.*?)\n\)\n", src, re.DOTALL)
    if not m:
        raise RuntimeError("TEXTS not found in gen-audio.sh")
    body = m.group(1)
    body = re.sub(r"#[^\n]*", "", body)
    tokens = re.findall(r'"([^"]+)"', body)
    seen = []
    dedup = []
    for t in tokens:
        if t not in seen:
            seen.append(t)
            dedup.append(t)
    return dedup


def tts(text, key):
    data = json.dumps({
        "model": MODEL,
        "voice": VOICE,
        "input": text,
        "speed": SPEED,
        "response_format": FMT,
    }).encode("utf-8")
    req = urllib.request.Request(
        "https://api.openai.com/v1/audio/speech",
        data=data,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    key = load_key()
    texts = parse_texts()
    print(f"[1/2] {len(texts)} 件の音声を OpenAI TTS ({MODEL}/{VOICE}) で生成...")
    manifest = {}
    failed = []
    for i, t in enumerate(texts, 1):
        h = hashlib.md5(t.encode("utf-8")).hexdigest()
        path = os.path.join(OUT_DIR, f"{h}.{FMT}")
        manifest[t] = f"{h}.{FMT}"
        if os.path.exists(path) and os.path.getsize(path) > 0:
            print(f"  [{i:3d}/{len(texts)}] {t} (既存スキップ)", flush=True)
            continue
        for attempt in range(3):
            try:
                audio = tts(t, key)
                with open(path, "wb") as f:
                    f.write(audio)
                print(f"  [{i:3d}/{len(texts)}] {t} ({len(audio)}B)", flush=True)
                break
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", "ignore")[:200]
                if e.code == 429:
                    wait = 3 + attempt * 3
                    print(f"  [{i:3d}/{len(texts)}] {t} → 429 rate limit, wait {wait}s")
                    time.sleep(wait)
                else:
                    print(f"  [{i:3d}/{len(texts)}] {t} → HTTP {e.code}: {body}")
                    if attempt == 2:
                        failed.append(t)
                    time.sleep(1)
            except Exception as e:
                print(f"  [{i:3d}/{len(texts)}] {t} → {type(e).__name__}: {e}")
                if attempt == 2:
                    failed.append(t)
                time.sleep(1)
        time.sleep(0.12)

    if failed:
        print(f"⚠️ 失敗 {len(failed)} 件: {failed[:10]}")
        for t in failed:
            h = hashlib.md5(t.encode("utf-8")).hexdigest()
            if not os.path.exists(os.path.join(OUT_DIR, f"{h}.{FMT}")):
                manifest.pop(t, None)

    print(f"[2/2] manifest.json 書き出し ({len(manifest)} 件)")
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False)
    print("完了:", OUT_DIR)


if __name__ == "__main__":
    sys.exit(main())
