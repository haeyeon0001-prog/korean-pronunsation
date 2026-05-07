#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  韓国語音声 生成スクリプト (macOS Jian Premium)
# ─────────────────────────────────────────────────────────────────────
#
#  使い方:
#    1. 下の TEXTS=( ... ) に新しい単語を追加 (重複可、ハッシュで自然に統合)
#    2. ./gen-audio.sh を実行
#    3. 不足分の .m4a が docs/audio/ に生成され、manifest.json が更新される
#    4. 既存エントリ・既存音声には一切影響しない (冪等)
#    5. 公開には: AUDIO_VERSION を docs/index.html で更新 → commit → push
#
#  音声仕様 (公開サイトの全音声と統一):
#    voice : Jian (Premium)   ← macOS の韓国語ネイティブ音声 (女性・プレミアム)
#    rate  : 160              ← 全公開音声と同じ
#    text  : "<word>."        ← 末尾ピリオドで途中切れを防止
#    codec : AAC m4a / 64kbps / mono / 22050Hz
#
#  事前準備 (初回のみ):
#    システム設定 → アクセシビリティ → 読み上げコンテンツ → システムの声 →
#    韓国語 → Jian (Premium) をダウンロード
#    確認: say -v 'Jian (Premium)' "안녕하세요"  で音が鳴ればOK
#
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/docs/audio"
MANIFEST="$OUT_DIR/manifest.json"
VOICE='Jian (Premium)'
RATE='160'
mkdir -p "$OUT_DIR"

# 生成対象テキスト一覧 (重複可)
TEXTS=(
    # ───── 子音の名前 (19) ─────
    "기역" "니은" "디귿" "리을" "미음" "비읍" "시옷" "이응" "지읒"
    "치읓" "키읔" "티읕" "피읖" "히읗"
    "쌍기역" "쌍디귿" "쌍비읍" "쌍시옷" "쌍지읒"

    # ───── 子音の例単語 ─────
    "가다" "나라" "다리" "라디오" "마음" "바다" "사랑" "아이" "자동차"
    "차" "커피" "타다" "파도" "하늘" "까마귀" "따뜻하다" "빨리" "싸다" "짜다"

    # ───── 母音 (21) ─────
    "아" "야" "어" "여" "오" "요" "우" "유" "으" "이"
    "애" "얘" "에" "예" "와" "왜" "외" "워" "웨" "위" "의"

    # ───── 50音表 (10子音 x 10基本母音) ─────
    "가" "갸" "거" "겨" "고" "교" "구" "규" "그" "기"
    "나" "냐" "너" "녀" "노" "뇨" "누" "뉴" "느" "니"
    "다" "댜" "더" "뎌" "도" "됴" "두" "듀" "드" "디"
    "라" "랴" "러" "려" "로" "료" "루" "류" "르" "리"
    "마" "먀" "머" "며" "모" "묘" "무" "뮤" "므" "미"
    "바" "뱌" "버" "벼" "보" "뵤" "부" "뷰" "브" "비"
    "사" "샤" "서" "셔" "소" "쇼" "수" "슈" "스" "시"
    "자" "쟈" "저" "져" "조" "죠" "주" "쥬" "즈" "지"
    "하" "햐" "허" "혀" "호" "효" "후" "휴" "흐" "히"

    # ───── 가나다 (10子音 x 11合成母音) ─────
    "개" "걔" "게" "계" "과" "괘" "괴" "궈" "궤" "귀" "긔"
    "내" "냬" "네" "녜" "놔" "놰" "뇌" "눠" "눼" "뉘" "늬"
    "대" "댸" "데" "뎨" "돠" "돼" "되" "둬" "뒈" "뒤" "듸"
    "래" "럐" "레" "례" "롸" "뢔" "뢰" "뤄" "뤠" "뤼" "릐"
    "매" "먜" "메" "몌" "뫄" "뫠" "뫼" "뭐" "뭬" "뮈" "믜"
    "배" "뱨" "베" "볘" "봐" "봬" "뵈" "붜" "붸" "뷔" "븨"
    "새" "섀" "세" "셰" "솨" "쇄" "쇠" "숴" "쉐" "쉬" "싀"
    "재" "쟤" "제" "졔" "좌" "좨" "죄" "줘" "줴" "쥐" "즤"
    "해" "햬" "헤" "혜" "화" "홰" "회" "훠" "훼" "휘" "희"

    # ───── バッチム例 ─────
    "학교" "밖" "한국" "앉다" "옷" "빛" "물" "일" "엄마" "김치" "입" "앞" "공항"

    # ───── 発音規則例 ─────
    "한국어" "음악" "꽃이" "있어요" "밥을"
    "식당" "입국" "책상" "낮잠"
    "좋다" "입학" "축하" "많다" "싫다"
    "국물" "한국말" "끝나다" "입니다" "감사합니다"
    "신라" "연락" "설날" "편리" "일년"
    "같이" "해돋이" "굳이" "붙여"
    "좋아요" "많아요" "싫어요" "넣어"
    "한국요리" "꽃잎" "색연필" "서울역"

    # ───── テスト用 ─────
    "안녕하세요"

    # ───── 練習語彙 (CV 30 + CVC 30) ─────
    "오다" "사다" "보다" "자다" "아기" "바나나" "도자기" "구두" "모자" "가수"
    "나무" "사자" "치마" "어머니" "아버지" "기차" "주소" "도시" "머리" "고기"
    "가게" "하나" "두부" "노래"
    "선생님" "가방" "책" "공책" "연필" "시간" "친구" "일본" "집"
    "밥" "음식" "행복" "가족" "동생" "형" "언니" "남자" "선물"
    "시장" "빵" "눈" "손" "병원" "약속"

    # ───── 平音 (평음) — 練習タブで使用 ─────
    "어디" "거기" "부자"

    # ───── 激音 (격음) — 練習タブで使用 ─────
    "스키" "우표" "지하" "채소" "크기" "포도" "화가" "고추" "이해"
    "조카" "초대" "취미" "태도" "호수" "티셔츠" "아파트" "스포츠"
    "스케이트" "피" "코" "토마토" "나이프" "케이크" "포테이토" "포크" "코코아"
    "피자" "스파게티" "스테이크" "치즈"

    # ───── 濃音 (농음) — 練習タブで使用 ─────
    "아빠" "오빠" "아저씨" "가짜" "진짜" "찌개" "쓰레기" "바빠요" "싸요" "깨"
    "때" "또" "아까" "이따가" "토끼" "코끼리" "따로" "어때" "쓰기" "어깨"
)

echo "[1/2] 不足分の音声を生成中 (voice='$VOICE' rate=$RATE)..."
TOTAL=${#TEXTS[@]}
IDX=0
GENERATED=0

for TEXT in "${TEXTS[@]}"; do
    IDX=$((IDX+1))
    HASH=$(printf '%s' "$TEXT" | md5 -q)
    FILE="$OUT_DIR/$HASH.m4a"
    AIFF="$OUT_DIR/$HASH.aiff"

    if [[ -f "$FILE" && -s "$FILE" ]]; then
        continue
    fi

    printf "  [%3d/%3d] 生成: %s\n" "$IDX" "$TOTAL" "$TEXT"

    if ! say -v "$VOICE" -r "$RATE" -o "$AIFF" "$TEXT."; then
        echo "  ⚠️  $TEXT の音声合成に失敗" >&2
        rm -f "$AIFF"
        continue
    fi

    if ! afconvert -f m4af -d aac -b 64000 "$AIFF" "$FILE" 2>/dev/null; then
        echo "  ⚠️  $TEXT の AAC 変換に失敗" >&2
        rm -f "$AIFF" "$FILE"
        continue
    fi

    rm -f "$AIFF"
    GENERATED=$((GENERATED+1))
done

find "$OUT_DIR" -maxdepth 1 -name '*.aiff' -delete 2>/dev/null || true

if [[ $GENERATED -eq 0 ]]; then
    echo "      新規生成なし (全ファイル既存)"
else
    echo "      新規生成: $GENERATED 件"
fi

# ────────────────────────────────────────────────────────────
# manifest.json 更新 (既存エントリを保持して TEXTS の分だけ追記)
# ────────────────────────────────────────────────────────────
echo "[2/2] manifest.json を更新..."
python3 - "$MANIFEST" "$OUT_DIR" "${TEXTS[@]}" <<'PYEOF'
import json, hashlib, os, sys

manifest_path = sys.argv[1]
out_dir = sys.argv[2]
texts = sys.argv[3:]

if os.path.exists(manifest_path):
    with open(manifest_path, encoding="utf-8") as f:
        m = json.load(f)
else:
    m = {}

added = 0
for t in texts:
    h = hashlib.md5(t.encode("utf-8")).hexdigest() + ".m4a"
    p = os.path.join(out_dir, h)
    if os.path.exists(p) and os.path.getsize(p) > 0:
        if m.get(t) != h:
            m[t] = h
            added += 1

with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(m, f, ensure_ascii=False, indent=0)
print(f"      manifest 合計: {len(m)} 件 (今回追加/更新: {added})")
PYEOF

echo ""
echo "✅ 完了: $OUT_DIR"
du -sh "$OUT_DIR"
echo ""
echo "次のステップ (公開する場合):"
echo "  1. docs/index.html の AUDIO_VERSION を更新 (例: 'YYYY-MM-DD' を入れる)"
echo "  2. git add docs/audio/*.m4a docs/audio/manifest.json docs/index.html"
echo "  3. git commit -m 'Add new audio'"
echo "  4. git push origin main"
