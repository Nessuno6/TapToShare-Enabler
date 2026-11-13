#!/system/bin/sh
# After boot: write the bypass file and flag, then re-check every 10 minutes.
MODDIR=${0%/*}
. "$MODDIR/common.sh"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 20
if ! has_nfc; then log "- no NFC on $(getprop ro.product.model), nothing to do"; exit 0; fi
apply
fixes=0
while [ $fixes -lt 5 ]; do
  sleep 600
  if [ "$(current)" != "1" ] || ! has_ge_flag; then
    log "! Tap to share setting or Play services flag was reset ($(sl_version)); re-applying"
    apply; fixes=$((fixes + 1))
  fi
done
log "! stopped re-applying until next boot"
