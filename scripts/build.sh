#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
HOST="${2:-../duckpad}"
HOST="$(cd "$HOST" && pwd)"
KIND="d2"
OUTPUT="$ROOT/dist/com.duckpad.$KIND.duckpad-plugin"
mkdir -p "$OUTPUT" "$ROOT/build/module-cache"
case "${1:-native}" in
 native) ARCHES=("$(uname -m)") ;;
 universal) ARCHES=(arm64 x86_64) ;;
 *) exit 64 ;;
esac
if [[ "$KIND" == mermaid ]]; then
 node "$HOST/scripts/markdown-preview/build-diagram-runtime.mjs" "$ROOT/build/mermaid.js"
 python3 "$ROOT/scripts/embed-runtime.py" "$ROOT/build/mermaid.js" "$ROOT/build/mermaid.c"
 cp "$HOST/Sources/DuckpadEditorAdapter/Resources/MarkdownEditor/THIRD_PARTY_NOTICES.txt" "$OUTPUT/THIRD_PARTY_NOTICES.txt"
fi
MODULES=()
for ARCH in "${ARCHES[@]}"; do
 mkdir -p "$ROOT/build/$ARCH"
 EXTRA=()
 if [[ "$KIND" == d2 ]]; then
  EXTRA+=("$HOST/Sources/DuckpadPluginSupport/NativeInstallerXPCProtocol.swift" "$HOST/Sources/DuckpadPluginSupport/D2Request.swift")
 else
  clang -arch "$ARCH" -mmacosx-version-min=13.0 -O2 -c "$ROOT/build/mermaid.c" -o "$ROOT/build/$ARCH/mermaid.o"
  EXTRA+=("$ROOT/build/$ARCH/mermaid.o")
 fi
 swiftc -swift-version 6 -target "$ARCH-apple-macosx13.0" -module-cache-path "$ROOT/build/module-cache" -O -emit-library   -module-name "Duckpad_d2_0_1_0" -I "$HOST/SDK/DuckpadNative/include"   "$HOST/SDK/DuckpadNative/Swift/DuckpadHost.swift" "$HOST"/SDK/DiagramPreview/Sources/*.swift   "${EXTRA[@]}" "$ROOT"/Sources/*.swift -framework AppKit -framework WebKit -framework Security   -o "$ROOT/build/$ARCH/module.dylib"
 MODULES+=("$ROOT/build/$ARCH/module.dylib")
done
if [[ "${#MODULES[@]}" == 1 ]]; then cp "${MODULES[0]}" "$OUTPUT/module.dylib"; else lipo -create "${MODULES[@]}" -output "$OUTPUT/module.dylib"; fi
codesign --force --sign "${DUCKPAD_PLUGIN_SIGN_IDENTITY:--}" --options runtime "$OUTPUT/module.dylib"
cp plugin.json Resources/*.strings "$OUTPUT/"
python3 - "$OUTPUT" <<'PYCODE'
import hashlib,pathlib,sys
root=pathlib.Path(sys.argv[1])
paths=sorted(p for p in root.iterdir() if p.name not in {'SHA256SUMS','SIGNATURE.ed25519'})
(root/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in paths))
PYCODE
printf 'Built: %s\n' "$OUTPUT"
