# Quick Share Tap to share enabler

A KernelSU / Magisk module that turns on Quick Share's **Tap to share** (share by tapping two
phones together over NFC) on rooted Samsung Galaxy phones that don't officially get it.
Nothing on `/system` is written: everything is mounted in memory or kept in app data.

## How it works

Quick Share decides whether Tap to share is supported in three places, and the module
handles each:

1. **The feature switch.** From Quick Share 13.9.02.31 on, the feature is hard-coded off. The
   module mounts Quick Share **13.9.02.22** (same Samsung signature) over the built-in app in
   memory.
2. **The model allowlist.** Quick Share only allows certain device codenames, unless its
   `hidden_setting.xml` has `tap_to_share_supported=true`. The module writes that file.
3. **Play services.** Play services only runs the NFC tap if Quick Share's version is at least
   its flag `45837040`. The module lowers that flag with `flagtool` (see below), which keeps
   the flag file in the order Play services expects.

After boot it re-checks every 10 minutes and re-applies if a Quick Share or Play services
update reset anything. Uninstalling removes the settings file and the flag override.

## Compatibility

Tested and working on a **Galaxy S25 Ultra** and a **Galaxy A17**.

Low-end devices may have problems: after the NFC tap, Quick Share sets up a Wi-Fi Direct
connection for the transfer, and a slow phone can take too long to do that, so the share
fails.

## Install

Needs root (KernelSU or Magisk) and a phone with NFC.

1. **Get Quick Share 13.9.02.22.** It's Samsung's app, so it isn't included here: download the
   Quick Share APK (package `com.samsung.android.app.sharelive`), version **13.9.02.22**, into
   your **Download** folder. The installer only accepts that exact build, checked by SHA-256:
   `c4889a538e3ca3afb0e6deefd08510ea29d1ac24034207de2c2d7a5b25e8fcd8`
2. Download `TapToShare_vX.Y.zip` from the
   [latest release](https://github.com/Nessuno6/TapToShare-Enabler/releases/latest) and install
   it in KernelSU or Magisk, then reboot.
3. Turn on NFC, then Quick Share settings > **Tap to share**.

The module's **Action** button (KernelSU) applies everything again and shows the result.

## Updates

`module.prop` points KernelSU / Magisk to [`update.json`](update.json), so the manager offers
new versions in its module list. An update reuses the Quick Share APK from the installed
module, so you don't need to download it again.

## Build

```bash
bash release.sh            # flagtool.dex + dist/TapToShare_vX.Y.zip + update.json
bash release.sh --publish  # also creates the GitHub release; then commit update.json
```

The version comes from the first `## vX.Y` heading in [CHANGELOG.md](CHANGELOG.md).
`flagtool` needs a JDK and the Android SDK's build-tools 36.0.0 (`ANDROID_HOME` /
`JAVA_HOME`, or Android Studio's default locations).

## flagtool

`flagtool/` is a small Java program run on the device with `app_process`. It sets or removes
entries in a Play services flag file (`files/phenotype/shared/<group>.pb`), inserting them
in sorted position, because Play services ignores entries appended at the end.

```text
CLASSPATH=flagtool.dex app_process /system/bin dev.deang.flagtool.Main FILE ID... [ID=N...] [-NAME...]
```
