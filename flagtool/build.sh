#!/usr/bin/env bash
# Builds flagtool.dex (run on the device with app_process) into ../module.
set -euo pipefail
cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null)/Android/Sdk}}"
JBR="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"
BT="$SDK/build-tools/36.0.0"
export JAVA_HOME="$JBR" PATH="$JBR/bin:$PATH"
D8="$BT/d8"; [ -f "$BT/d8.bat" ] && D8="$BT/d8.bat"
rm -rf out && mkdir -p out/classes
javac -source 11 -target 11 -Xlint:-options -encoding UTF-8 -d out/classes $(find src -name '*.java')
"$D8" --min-api 30 --output out $(find out/classes -name '*.class')
cp out/classes.dex ../module/flagtool.dex
rm -rf out
echo "built module/flagtool.dex"
