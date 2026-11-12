#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DONOR="${1:-$ROOT/donors/FilzaSlop_1.0.3.ipa}"
SDK="${FF_SDK:-$(xcrun --sdk iphoneos --show-sdk-path)}"
CLANG="${FF_CLANG:-$(xcrun --sdk iphoneos -f clang)}"
STRIP="${FF_STRIP:-$(xcrun --find strip)}"
PYTHON="${FF_PYTHON:-python3}"
BUILD="${TMPDIR:-/tmp}/ffcache-clean-build"
DIST="$ROOT/dist/clean"
IPA_NAME="FFCacheManager-5.6.2-4-CLEAN.ipa"
IPA="$BUILD/$IPA_NAME"
APP="$BUILD/Payload/FFCacheManager.app"
FRAMEWORK="$APP/Frameworks/CoreTelemetry.framework"
EXECUTABLE="$APP/FFCacheManager"

[[ -f "$DONOR" ]] || { echo "donor IPA not found: $DONOR" >&2; exit 2; }
[[ -d "$SDK" ]] || { echo "iPhoneOS SDK not found: $SDK" >&2; exit 2; }
"$PYTHON" -c 'import PIL, lief' >/dev/null
rm -rf "$BUILD" "$DIST"
mkdir -p "$FRAMEWORK" "$DIST" "$ROOT/server_payloads"

"$PYTHON" "$ROOT/extract_bridge.py" "$DONOR" "$BUILD/FilzaApplySandboxExt.dylib"
"$STRIP" -S "$BUILD/FilzaApplySandboxExt.dylib" -o "$BUILD/FilzaApplySandboxExt.stripped.dylib"
"$PYTHON" "$ROOT/set_install_name.py" "$BUILD/FilzaApplySandboxExt.stripped.dylib" "$BUILD/FilzaApplySandboxExt.named.dylib" '@rpath/CoreTelemetry.framework/CoreTelemetry'
"$PYTHON" "$ROOT/protect_bridge.py" "$BUILD/FilzaApplySandboxExt.named.dylib" "$FRAMEWORK/CoreTelemetry" "$BUILD/protected-core.json"

"$PYTHON" "$ROOT/generate_app_icons.py" "$ROOT/resources/brand.png" "$APP"
ICON_DIGEST="$($PYTHON - "$APP" <<'PY'
import hashlib, sys
from pathlib import Path
app = Path(sys.argv[1])
names = ['AppIcon60x60@2x.png','AppIcon60x60@3x.png','AppIcon76x76.png','AppIcon76x76@2x.png','AppIcon83.5x83.5@2x.png','AppIcon1024.png']
parts = [hashlib.sha256((app/n).read_bytes()).hexdigest() for n in names]
print(hashlib.sha256('|'.join(parts).encode()).hexdigest())
PY
)"
export ICON_DIGEST
"$PYTHON" - "$BUILD/protected-core.json" "$BUILD/ProtectedConfig.h" <<'PY'
import json, os, sys
m=json.load(open(sys.argv[1]))
a,b=m['slices']
open(sys.argv[2],'w').write('\n'.join([
 f'#define FFCORE_TEXT_SHA256_A @"{a["text_sha256"]}"',
 f'#define FFCORE_EXPORT_SHA256_A @"{a["export_sha256"]}"',
 f'#define FFCORE_SECTION_SHA256_A @"{a["section_sha256"]}"',
 f'#define FFCORE_TEXT_SHA256_B @"{b["text_sha256"]}"',
 f'#define FFCORE_EXPORT_SHA256_B @"{b["export_sha256"]}"',
 f'#define FFCORE_SECTION_SHA256_B @"{b["section_sha256"]}"',
 f'#define FFICON_BUNDLE_SHA256 @"{os.environ["ICON_DIGEST"]}"', '']))
PY

cp "$ROOT/main.m" "$BUILD/main.m"
for f in FFKernelExploit.h FFKernelExploit.m FFWorseQuery.h FFWorseQuery.m FFWorseQueryPolicy.h; do cp "$ROOT/$f" "$BUILD/$f"; done
mkdir -p "$BUILD/vendor/worse_query"
cp "$ROOT/vendor/worse_query"/* "$BUILD/vendor/worse_query/"

COMMON=(-arch arm64 -target arm64-apple-ios15.0 -isysroot "$SDK" -fobjc-arc -Os -fstack-protector-strong -fvisibility=hidden -fomit-frame-pointer -fno-ident -Werror -Wno-deprecated-declarations -DFF_RELEASE_BUILD=1 -DFF_REQUIRE_SIGNED_RESPONSES=1 -DFF_3105_MCM=1 -I "$BUILD")
"$CLANG" "${COMMON[@]}" -c "$BUILD/main.m" -o "$BUILD/main.o"
OBJECTS=("$BUILD/main.o")
for src in FFKernelExploit.m FFWorseQuery.m vendor/worse_query/worse_query.m; do
  obj="$BUILD/$(basename "$src" .m).o"
  "$CLANG" "${COMMON[@]}" -fblocks -Wno-incompatible-pointer-types-discards-qualifiers -Wno-unused-function -Wno-unused-variable -Wno-unused-parameter -c "$BUILD/$src" -o "$obj"
  OBJECTS+=("$obj")
done

"$CLANG" -target arm64-apple-ios15.0 -isysroot "$SDK" -Wl,-platform_version,ios,15.0,15.0 -Wl,-e,_main -Wl,-adhoc_codesign -Wl,-dead_strip "${OBJECTS[@]}" -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework Security -framework UniformTypeIdentifiers -framework IOSurface -lobjc -lSystem -o "$EXECUTABLE"
"$STRIP" -x "$EXECUTABLE"
cp "$ROOT/FrameworkInfo.plist" "$FRAMEWORK/Info.plist"
"$PYTHON" "$ROOT/make_clean_info_plist.py" "$ROOT/Info.plist" "$APP/Info.plist"
"$PYTHON" "$ROOT/build_assembly_package.py" "$ROOT/game_files" "$ROOT/server_payloads/ASSEMBLY_package.ffasm"
"$PYTHON" "$ROOT/make_ipa.py" "$BUILD" "$IPA"
"$PYTHON" "$ROOT/verify_clean_build.py" "$BUILD" "$IPA_NAME"
"$PYTHON" "$ROOT/generate_release_manifest.py" "$BUILD" "$BUILD/release_manifest.json"
cp "$BUILD/release_manifest.json" "$BUILD/release_manifest_releases.json"
HASH="$(shasum -a 256 "$IPA" | awk '{print toupper($1)}')"
SHORT="${HASH:0:12}"
cp "$IPA" "$DIST/FFCacheManager-5.6.2-4-CLEAN-$SHORT.ipa"
cp "$IPA" "$DIST/FFCacheManager-CLEAN.ipa"
printf '%s *%s\n' "$HASH" "FFCacheManager-CLEAN.ipa" > "$DIST/FFCacheManager-CLEAN.ipa.sha256"
cp "$BUILD/release_manifest.json" "$DIST/release_manifest.json"
cp "$BUILD/release_manifest_releases.json" "$DIST/release_manifest_releases.json"
printf 'CLEAN BUILD PASS\nIPA: %s\nSHA-256: %s\n' "$DIST/FFCacheManager-CLEAN.ipa" "$HASH"
