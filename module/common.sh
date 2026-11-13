# Shared by service.sh, action.sh and uninstall.sh. Source with MODDIR set.
#
# Quick Share decides Tap to share support in TapToShareRepository.supportsTapToShare:
#  1. FEATURE_TAP_TO_SHARE: hardcoded false from 13.9.02.31, so the module mounts 13.9.02.22
#     (same Samsung signature) over /system/priv-app/ShareLive in memory.
#  2. Device codename starts with q8/b8/h8/r14, or shared_prefs/hidden_setting.xml has
#     tap_to_share_supported=true. The module writes that file.
#  3. Play services Nearby and the MDE kit "tap to share" capability (bit 2048).
# It then writes the result to Settings.System quickshare_tap_to_share_supported itself.
KEY=quickshare_tap_to_share_supported
SL=com.samsung.android.app.sharelive
PREFS=/data/data/$SL/shared_prefs
LOG="$MODDIR/taptoshare.log"

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; echo "$*"; }

has_nfc() { pm list features 2>/dev/null | grep -q 'feature:android.hardware.nfc$'; }

current() { settings get system $KEY 2>/dev/null; }

sl_version() { dumpsys package $SL 2>/dev/null | grep -m1 versionName | sed 's/.*=//'; }

# Writes hidden_setting.xml (the model allowlist bypass) with Quick Share's own owner and label.
write_hidden() {
  [ -d "$PREFS" ] || return 1
  if grep -q 'tap_to_share_supported" value="true' "$PREFS/hidden_setting.xml" 2>/dev/null; then return 0; fi
  am force-stop $SL >/dev/null 2>&1
  OWN=$(stat -c %u:%g "$PREFS/..")
  cat > "$PREFS/hidden_setting.xml" <<X
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="tap_to_share_supported" value="true" />
</map>
X
  chown $OWN "$PREFS/hidden_setting.xml"; chmod 660 "$PREFS/hidden_setting.xml"
  restorecon "$PREFS/hidden_setting.xml" 2>/dev/null
  log "- wrote hidden_setting.xml"
}

# Play services then runs the NFC tap ("Gesture Exchange") only if Quick Share's versionCode is at
# least flag 45837040 (default 1390501000 = 13.9.05.01). That flag lives in the shared flag file
# below, looked up by numeric ID in sorted order, so flagtool inserts it in place.
GMS=com.google.android.gms
GE_FLAGS="/data/data/$GMS/files/phenotype/shared/com.google.android.gms.gestureexchange#com.google.android.gms.pb"
GE_SET="45837040=1"

flagtool() { CLASSPATH="$MODDIR/flagtool.dex" app_process /system/bin dev.deang.flagtool.Main "$@"; }

has_ge_flag() {
  [ -f "$GE_FLAGS" ] || return 1
  T=/data/local/tmp/t2s_check.pb
  cp "$GE_FLAGS" $T || return 1
  r=$(flagtool $T $GE_SET 2>/dev/null)
  rm -f $T
  [ "$r" = "unchanged" ]
}

gms_kill() { for p in $(pidof $GMS $GMS.persistent $GMS.unstable $GMS.ui); do kill -9 $p; done; }

set_ge_flag() {
  [ -f "$GE_FLAGS" ] || { log "! no gestureexchange flag file yet"; return 1; }
  has_ge_flag && return 0
  GU=$(stat -c %u /data/data/$GMS)
  gms_kill
  r=$(flagtool "$GE_FLAGS" $GE_SET 2>&1)
  chown $GU:$GU "$GE_FLAGS"; chmod 600 "$GE_FLAGS"; restorecon "$GE_FLAGS" 2>/dev/null
  rm -rf /data/data/$GMS/app_phenotype_shared/* /data/user_de/0/$GMS/app_phenotype_shared/*
  gms_kill
  if has_ge_flag; then log "- Play services minimum Quick Share version lowered ($r)"; else log "! setting gestureexchange flag failed: $r"; return 1; fi
}

apply() {
  write_hidden || { log "! Quick Share data folder missing; open Quick Share once"; return 1; }
  set_ge_flag
  [ "$(current)" = "1" ] || { settings put system $KEY 1; am force-stop $SL >/dev/null 2>&1; }
  log "- Quick Share $(sl_version), $KEY=$(current)"
}
