ui_print " "
ui_print "*********************************"
ui_print "  Quick Share Tap to share enabler"
ui_print "*********************************"
if pm list features 2>/dev/null | grep -q 'feature:android.hardware.nfc$'; then
  ui_print "- This device has NFC"
else
  ui_print "! This device has no NFC: Tap to share can't work here"
fi

# Quick Share 13.9.02.22 is Samsung's app and isn't included. The user downloads it; it's
# accepted only if it's exactly that build (SHA-256 below). On a module update the copy
# from the installed module is reused.
SL_VER=13.9.02.22
SL_SHA=c4889a538e3ca3afb0e6deefd08510ea29d1ac24034207de2c2d7a5b25e8fcd8
APK=
for f in /data/adb/modules/taptoshare_enable/sl/ShareLive.apk /sdcard/Download/*.apk /storage/emulated/0/Download/*.apk; do
  [ -f "$f" ] || continue
  if [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$SL_SHA" ]; then APK=$f; break; fi
done
if [ -z "$APK" ]; then
  ui_print "! Quick Share $SL_VER not found."
  ui_print "  Download the Quick Share APK, version $SL_VER"
  ui_print "  (package com.samsung.android.app.sharelive)"
  ui_print "  into Download, then install this zip again."
  abort "! Expected SHA-256: $SL_SHA"
fi
ui_print "- Using Quick Share $SL_VER from $APK"
mkdir -p "$MODPATH/sl"
cp "$APK" "$MODPATH/sl/ShareLive.apk" || abort "! Couldn't copy the APK"

set_perm_recursive "$MODPATH" 0 0 0755 0644
for s in post-fs-data.sh service.sh action.sh uninstall.sh; do set_perm "$MODPATH/$s" 0 0 0755; done
ui_print "- Active after the next reboot (or a soft reboot from KernelSU)"
