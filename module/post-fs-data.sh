#!/system/bin/sh
# Before Android starts: put Quick Share 13.9.02.22 over the built-in one (newer builds
# hardcode Tap to share off). Bind mount in memory only; nothing on /system is written.
MODDIR=${0%/*}
DST=/system/priv-app/ShareLive
DIR=$MODDIR/sl_mnt
LOG=$MODDIR/taptoshare.log
echo "$(date '+%m-%d %H:%M:%S') post-fs-data" > "$LOG"
[ -f "$DST/ShareLive.apk" ] || { echo "! $DST missing" >> "$LOG"; exit 0; }
[ -f "$MODDIR/sl/ShareLive.apk" ] || { echo "! Quick Share APK missing from the module: reinstall it" >> "$LOG"; exit 0; }
if cmp -s "$DST/ShareLive.apk" "$MODDIR/sl/ShareLive.apk"; then echo "- already mounted" >> "$LOG"; exit 0; fi
rm -rf "$DIR" && mkdir -p "$DIR"
cp "$MODDIR/sl/ShareLive.apk" "$DIR/ShareLive.apk"
chown -R 0:0 "$DIR"; chmod 755 "$DIR"; chmod 644 "$DIR/ShareLive.apk"
chcon -R u:object_r:system_file:s0 "$DIR"
nsenter -t 1 -m -- mount -o bind "$DIR" "$DST" 2>/dev/null || mount -o bind "$DIR" "$DST"
if cmp -s "$DST/ShareLive.apk" "$MODDIR/sl/ShareLive.apk"; then
  echo "- Quick Share 13.9.02.22 mounted" >> "$LOG"
else
  echo "! mount failed" >> "$LOG"
fi
