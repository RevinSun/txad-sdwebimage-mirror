#!/usr/bin/env bash
# Tools/txadify_local.sh
# 用法：
#   ./Tools/txadify_local.sh /absolute/path/to/your/local/SDWebImage
set -euo pipefail

SRC=${1:? "/Users/revin-sun/Desktop/Code/TanxSDK-iOS/TanxSDK/Core/Common/SDWebImage"}
OUT=Sources/TXAdWebImage

rm -rf "$OUT"
mkdir -p "$OUT"

echo "[1/4] Namespacing from: $SRC"
python3 Tools/txad_rename.py "$SRC" "$OUT"

echo "[2/4] Generate umbrella header"
mkdir -p "$OUT/include/TXAdWebImage"
UMBRELLA="$OUT/include/TXAdWebImage/TXAdWebImage.h"
cat > "$UMBRELLA" <<'EOF'
/*
 Umbrella header for TXAdWebImage (namespaced from SDWebImage).
 Keep original MIT license from SDWebImage project in Sources/TXAdWebImage/LICENSE.
*/
EOF
find "$OUT/include/TXAdWebImage" -type f -name "*.h" ! -name "TXAdWebImage.h" | sort | while read -r hdr; do
  base=$(basename "$hdr")
  echo "#import \"$base\"" >> "$UMBRELLA"
done

echo "[3/4] Generate module.modulemap (Swift/Clang module 可选)"
mkdir -p "$OUT/Modules"
cat > "$OUT/Modules/module.modulemap" <<'EOF'
module TXAdWebImage {
  umbrella header "include/TXAdWebImage/TXAdWebImage.h"
  export *
  module * { export * }
}
EOF

echo "[4/4] Copy LICENSE"
cp "$SRC/LICENSE" "$OUT/" || true

echo "Done. Output => $OUT"
