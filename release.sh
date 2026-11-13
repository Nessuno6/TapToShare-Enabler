#!/usr/bin/env bash
# Builds the module zip for the version in CHANGELOG.md's first "## vX.Y" heading and writes
# update.json. With --publish it also creates the GitHub release. Then commit and push
# update.json: KernelSU / Magisk read it from the main branch to offer updates.
set -euo pipefail
cd "$(dirname "$0")"
REPO=Nessuno6/TapToShare-Enabler
TAG=$(sed -n 's/^## \(v[0-9][0-9.]*\)$/\1/p' CHANGELOG.md | head -1)
VC=$(echo "${TAG#v}" | awk -F. '{print $1*100 + $2}')
OUT="dist/TapToShare_v${TAG#v}.zip"

bash flagtool/build.sh
rm -rf stage dist && mkdir -p stage dist
cp -r module/. stage/
sed -i -e "s/^version=.*/version=$TAG/" -e "s/^versionCode=.*/versionCode=$VC/" stage/module.prop
python -I - "$OUT" <<'PY'
import os, sys, zipfile
out = sys.argv[1]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk("stage"):
        for f in sorted(files):
            p = os.path.join(root, f)
            a = os.path.relpath(p, "stage").replace(os.sep, "/")
            zi = zipfile.ZipInfo.from_file(p, a)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = (0o100755 if a.endswith(".sh") or a.endswith("update-binary") else 0o100644) << 16
            data = open(p, "rb").read()
            if not a.endswith(".dex"):
                data = data.replace(b"\r\n", b"\n")  # Unix line endings for the device
            z.writestr(zi, data)
for i in zipfile.ZipFile(out).infolist():
    print(f"{i.file_size:>8}  {i.filename}")
PY
rm -rf stage

cat > update.json <<JSON
{
  "version": "$TAG",
  "versionCode": $VC,
  "zipUrl": "https://github.com/$REPO/releases/download/$TAG/$(basename "$OUT")",
  "changelog": "https://raw.githubusercontent.com/$REPO/main/CHANGELOG.md"
}
JSON
echo "built $OUT, wrote update.json ($TAG, versionCode $VC)"

if [ "${1:-}" = "--publish" ]; then
  NOTES=$(awk -v t="## $TAG" '$0==t{f=1;next} /^## /{f=0} f' CHANGELOG.md)
  gh release create "$TAG" "$OUT" --repo "$REPO" --title "Tap to share enabler $TAG" --notes "$NOTES"
fi
