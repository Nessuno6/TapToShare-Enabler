#!/system/bin/sh
SL=com.samsung.android.app.sharelive
rm -f /data/data/$SL/shared_prefs/hidden_setting.xml
settings put system quickshare_tap_to_share_supported 0
am force-stop $SL >/dev/null 2>&1
# Remove the Play services minimum-version override (Play services restarts briefly).
MODDIR=${0%/*}
F="/data/data/com.google.android.gms/files/phenotype/shared/com.google.android.gms.gestureexchange#com.google.android.gms.pb"
if [ -f "$F" ] && [ -f "$MODDIR/flagtool.dex" ]; then
  GU=$(stat -c %u /data/data/com.google.android.gms)
  for p in $(pidof com.google.android.gms com.google.android.gms.persistent); do kill -9 $p; done
  CLASSPATH="$MODDIR/flagtool.dex" app_process /system/bin dev.deang.flagtool.Main "$F" -45837040 >/dev/null 2>&1
  chown $GU:$GU "$F"; chmod 600 "$F"; restorecon "$F" 2>/dev/null
  rm -rf /data/data/com.google.android.gms/app_phenotype_shared/*
fi
