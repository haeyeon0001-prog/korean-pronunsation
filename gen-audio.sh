#!/usr/bin/env bash
# macOS `say -v 'Jian (Premium)'` (ネイティブ韓国語 TTS) で音声生成 → AAC/.m4a 変換
# 出力: docs/audio/<md5>.m4a と manifest.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/docs/audio"
MANIFEST="$OUT_DIR/manifest.json"
mkdir -p "$OUT_DIR"

# 生成対象テキスト一覧 (重複はハッシュで自然に除外)
TEXTS=(
    # 子音の名前 (19)
    "기역" "니은" "디귿" "리을" "미음" "비읍" "시옷" "이응" "지읒"
    "치읓" "키읔" "티읕" "피읖" "히읗"
    "쌍기역" "쌍디귿" "쌍비읍" "쌍시옷" "쌍지읒"
    # 子音の例単語
    "가다" "나라" "다리" "라디오" "마음" "바다" "사랑" "아이" "자동차"
    "차" "커피" "타다" "파도" "하늘" "까마귀" "따뜻하다" "빨리" "싸다" "짜다"
    # 母音 (21)
    "아" "야" "어" "여" "오" "요" "우" "유" "으" "이"
    "애" "얘" "에" "예" "와" "왜" "외" "워" "웨" "위" "의"
    # 50音表 (10子音 x 10基本母音)
    "가" "갸" "거" "겨" "고" "교" "구" "규" "그" "기"
    "나" "냐" "너" "녀" "노" "뇨" "누" "뉴" "느" "니"
    "다" "댜" "더" "뎌" "도" "됴" "두" "듀" "드" "디"
    "라" "랴" "러" "려" "로" "료" "루" "류" "르" "리"
    "마" "먀" "머" "며" "모" "묘" "무" "뮤" "므" "미"
    "바" "뱌" "버" "벼" "보" "뵤" "부" "뷰" "브" "비"
    "사" "샤" "서" "셔" "소" "쇼" "수" "슈" "스" "시"
    "아" "야" "어" "여" "오" "요" "우" "유" "으" "이"
    "자" "쟈" "저" "져" "조" "죠" "주" "쥬" "즈" "지"
    "하" "햐" "허" "혀" "호" "효" "후" "휴" "흐" "히"
    # 가나다 (10子音 x 11合成母音)
    "개" "걔" "게" "계" "과" "괘" "괴" "궈" "궤" "귀" "긔"
    "내" "냬" "네" "녜" "놔" "놰" "뇌" "눠" "눼" "뉘" "늬"
    "대" "댸" "데" "뎨" "돠" "돼" "되" "둬" "뒈" "뒤" "듸"
    "래" "럐" "레" "례" "롸" "뢔" "뢰" "뤄" "뤠" "뤼" "릐"
    "매" "먜" "메" "몌" "뫄" "뫠" "뫼" "뭐" "뭬" "뮈" "믜"
    "배" "뱨" "베" "볘" "봐" "봬" "뵈" "붜" "붸" "뷔" "븨"
    "새" "섀" "세" "셰" "솨" "쇄" "쇠" "숴" "쉐" "쉬" "싀"
    "애" "얘" "에" "예" "와" "왜" "외" "워" "웨" "위" "의"
    "재" "쟤" "제" "졔" "좌" "좨" "죄" "줘" "줴" "쥐" "즤"
    "해" "햬" "헤" "혜" "화" "홰" "회" "훠" "훼" "휘" "희"
    # バッチム例
    "학교" "밖" "한국" "앉다" "옷" "빛" "물" "일" "엄마" "김치" "입" "앞" "공항" "사랑"
    # 発音規則例
    "한국어" "음악" "꽃이" "있어요" "밥을"
    "식당" "입국" "책상" "낮잠"
    "좋다" "입학" "축하" "많다" "싫다"
    "국물" "한국말" "끝나다" "입니다" "감사합니다"
    "신라" "연락" "설날" "편리" "일년"
    "같이" "해돋이" "굳이" "붙여"
    "좋아요" "많아요" "싫어요" "넣어"
    "한국요리" "꽃잎" "색연필" "서울역"
    # テスト用
    "안녕하세요"
    # 練習語彙 (CV 30 + CVC 30)
    "오다" "사다" "보다" "자다" "아기" "바나나" "도자기" "구두" "모자" "가수"
    "나무" "사자" "치마" "어머니" "아버지" "기차" "주소" "도시" "머리" "고기"
    "가게" "하나" "두부" "노래"
    "선생님" "가방" "책" "공책" "연필" "시간" "친구" "일본" "집"
    "밥" "음식" "행복" "가족" "동생" "형" "언니" "남자" "선물"
    "시장" "빵" "눈" "손" "병원" "약속"
)

echo "[1/2] 音声を生成中 (say -v Yuna → AAC/.m4a)..."
TOTAL=${#TEXTS[@]}
IDX=0

for TEXT in "${TEXTS[@]}"; do
    IDX=$((IDX+1))
    HASH=$(printf '%s' "$TEXT" | md5 -q)
    FILE="$OUT_DIR/$HASH.m4a"
    AIFF="$OUT_DIR/$HASH.aiff"

    # 既に生成済みならスキップ
    if [[ -f "$FILE" && -s "$FILE" ]]; then
        printf "\r  [%3d/%3d] %s (既存)        " "$IDX" "$TOTAL" "$TEXT"
        continue
    fi

    printf "\r  [%3d/%3d] %s              " "$IDX" "$TOTAL" "$TEXT"

    # Jian Premium (韓国語ネイティブ) で AIFF 出力 → AAC m4a 変換
    # 文末にピリオドを付けないと say が途中で切れることがある (例: 안녕하세요)
    if ! say -v 'Jian (Premium)' -r 160 -o "$AIFF" "$TEXT."; then
        echo ""
        echo "  警告: $TEXT の音声合成に失敗"
        rm -f "$AIFF"
        continue
    fi

    if ! afconvert -f m4af -d aac -b 64000 "$AIFF" "$FILE" 2>/dev/null; then
        echo ""
        echo "  警告: $TEXT の AAC 変換に失敗"
        rm -f "$AIFF" "$FILE"
        continue
    fi

    rm -f "$AIFF"
done
echo ""

# 古い .mp3 は不要なので掃除 (manifest に残らなければ再生されない)
find "$OUT_DIR" -maxdepth 1 -name '*.aiff' -delete 2>/dev/null || true

echo "[2/2] manifest.json を書き出し..."
python3 <<EOF
import json, hashlib, os
texts = $(printf '%s\n' "${TEXTS[@]}" | python3 -c "import sys,json; print(json.dumps([l.rstrip() for l in sys.stdin if l.strip()]))")
m = {}
for t in texts:
    h = hashlib.md5(t.encode('utf-8')).hexdigest()
    fn = h + '.m4a'
    path = os.path.join("$OUT_DIR", fn)
    if os.path.exists(path) and os.path.getsize(path) > 0:
        m[t] = fn
with open("$MANIFEST", 'w', encoding='utf-8') as f:
    json.dump(m, f, ensure_ascii=False, indent=0)
print(f"  → {len(m)} 件を manifest に登録")
EOF

echo ""
echo "完了: $OUT_DIR"
du -sh "$OUT_DIR"
