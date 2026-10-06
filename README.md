# OneOne module

Source and release packages for the OneOne Magisk/Kitsune Mask module on
LDPlayer (Android x86_64, 960x540).

## Contents

- `magisk_module/`: module scripts, bundled templates and finder executable.
- `finder_v2_src/`: complete native finder source, third-party headers and NDK build script.
- `update.json`: metadata used by the native Magisk/Kitsune module updater.

Account files, per-machine configuration, device logs, Manager and Windows
watchdog and local test screenshots are not included. `Module.zip` / ktools is a separate third-party
module and is not part of this repository.

## Installation and online updates

Download `OneOne.zip` from this repository's Releases and install it in
Magisk/Kitsune Mask. An older installation without `updateJson` must be updated
manually once. Follow the installer's reboot instructions.

Later releases are discoverable through the module's Update action. This does
not add a polling loop to the bot and does not silently install updates.
Each Android instance has its own installed module and must be updated.

The shared `config.json` and `Acc.csv` are supplied separately. The module
searches the shared `Pictures/Tools` and `Misc/Tools` mappings and its local
`/sdcard/oneone` fallback; do not commit credentials to this repository.

## Build on Windows

Install Android NDK r30 under `.tools/android-ndk-r30`, then run:

```powershell
./finder_v2_src/build.ps1
./magisk_module/build_zip.ps1
```

Packaging increases `versionCode` and generates matching `update.json`.
Use `./magisk_module/build_zip.ps1 -NoVersionBump` to repack the same version.
Upload `OneOne.zip` to the release tag matching `version` BEFORE publishing
the new `update.json` on `main`.

This release adds online-update metadata only. It does not fix the separate
bot logic issues identified in the code review and has not been flashed to
the running LD instance during publishing.

## Third-party code

`finder_v2_src/third_party/stb_image.h` and the retained LodePNG sources carry
their original license notices. The finder currently uses stb_image;
LodePNG is retained for source completeness.
