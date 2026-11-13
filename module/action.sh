#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common.sh"
if ! has_nfc; then echo "! This device has no NFC, so Tap to share can't work on it."; exit 0; fi
case "$(sl_version)" in 13.9.02.22) ;; *) echo "! Quick Share is $(sl_version), not 13.9.02.22: the overlay isn't mounted yet (soft reboot)";; esac
apply
sleep 3
echo "- after Quick Share's own check: $KEY=$(current)"
echo "- Then: Quick Share settings > Tap to share > On, NFC on on both phones."
