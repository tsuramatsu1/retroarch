# RetroArch for jailbroken PS5

Build recipes for a RetroArch payload for a jailbroken PS5, with 13 libretro
cores.

The PS5 port of RetroArch itself is **John Tornblom's**, distributed as part of
[ps5-payload-dev/websrv](https://github.com/ps5-payload-dev/websrv). This
repository is that port plus extra cores; all of the porting work is his.

## Systems included

| Core | System |
|---|---|
| `fceumm` | NES / Famicom |
| `snes9x2010` | SNES |
| `genesis_plus_gx` | Mega Drive / Master System / Game Gear |
| `gambatte` | Game Boy / Game Boy Color |
| `mednafen_gba` | Game Boy Advance |
| `mednafen_psx` | PlayStation |
| `pcsx_rearmed` | PlayStation (faster) |
| `desmume2015` | Nintendo DS |
| `mame2003_plus` | Arcade |
| `mame2010` | Arcade (newer romsets) |
| `puae` / `puae2021` | Amiga |
| `vice_x64` | Commodore 64 |

## Install

1. Jailbreak the console and make sure `websrv` (the Homebrew Launcher) is
   running.
2. Unzip `RetroArch-PS5.zip` and copy the `RetroArch` folder to `homebrew/` on
   internal storage or a USB drive, so you end up with one of:

   ```
   /data/homebrew/RetroArch
   /mnt/usb0/homebrew/RetroArch      (usb0 through usb7)
   /mnt/ext0/homebrew/RetroArch      (ext0, ext1)
   ```

3. Open the Homebrew Launcher on the console and pick **RetroArch**.

BIOS files in`.config/retroarch/system`

## Using it

Load a game with **Load Content**, then browse to your ROM. RetroArch picks the
core automatically for most systems; where two cores can open the same file it
asks which to use.

The menu is RGUI (the plain list-style interface).

- **Open or close the menu while a game is running:** press L3 + R3 (click both
  analog sticks).
- **Confirm / cancel:** cross and circle are swapped to match PlayStation
  convention, so cross confirms.
- **Touchpad as a pointer:** the DualSense touchpad moves the on-screen pointer
  and pressing it clicks. Useful for the Nintendo DS touch screen and for arcade
  games with a trackball or lightgun.

Settings are saved when you exit through **Quit RetroArch** in the menu. If the
console is powered off with RetroArch still running, changes made in that session
are lost.

## Rebuilding

| Script | Builds |
|---|---|
| `build-sdl.sh` | SDL2 with the DualSense touchpad patch - **run before `build.sh`** |
| `build.sh` | the frontend, `retroarch.elf` |
| `build-<core>.sh` | one core each |
| `fetch-assets.sh`, `fetch-databases.sh` | menu assets and game databases |

`build-sdl.sh` matters: the SDL2 in the prebuilt sysroot is stock, and a frontend
linked against it has no touchpad pointer. RetroArch derives
`RETRO_DEVICE_POINTER` from `SDL_GetMouseState()` and its SDL input driver reads
neither SDL touch nor `SDL_CONTROLLERTOUCHPAD` events, so the fix belongs in SDL -
see `patches/sdl-ps5-touchpad.py`.

You need the [ps5-payload-dev/sdk](https://github.com/ps5-payload-dev/sdk)
toolchain plus the prebuilt sysroot, on Ubuntu 24.04 (the SDK pins clang/lld 18):

```sh
sudo apt-get install -y clang-18 lld-18 llvm-18 llvm-18-dev build-essential wget unzip

wget https://github.com/ps5-payload-dev/sdk/releases/latest/download/ps5-payload-sdk.zip
sudo unzip -d /opt ps5-payload-sdk.zip

# prebuilt third-party libs (SDL2, ffmpeg, freetype, zlib, ...); extracts over /
wget https://github.com/ps5-payload-dev/pacbrew-repo/releases/latest/download/ps5-payload-dev.tar.gz
sudo tar xf ps5-payload-dev.tar.gz -C /

export PS5_PAYLOAD_SDK=/opt/ps5-payload-sdk
./build-sdl.sh          # patched SDL, before the frontend
./build.sh              # retroarch.elf
./build-fceumm.sh       # a core
./fetch-assets.sh && ./fetch-databases.sh
```

## Licence

RetroArch and the websrv port are **GPLv3**; the full text is in
[LICENSE](LICENSE). The files taken from websrv (`build.sh`, `homebrew.js`) keep
their original copyright and licence headers. `build.sh` has been modified here -
it no longer overwrites an existing `retroarch.cfg` on rebuild.

The cores are **not** all under the same licence:

| Core | Licence |
|---|---|
| `fceumm`, `gambatte`, `mednafen_gba`, `mednafen_psx`, `pcsx_rearmed`, `desmume2015`, `puae`, `puae2021`, `vice_x64` | GPLv2 |
| `genesis_plus_gx`, `snes9x2010` | Non-commercial |
| `mame2003_plus`, `mame2010` | MAME licence (non-commercial) |

No binaries are committed to this repository, but **the release zip does contain
them**, so those terms apply to the releases: the non-commercial cores may not be
redistributed commercially, and MAME's licence has its own conditions. The GPLv2
cores are built from the upstream sources named in each `build-*.sh`, which serve
as the corresponding source.

Bundled fonts and menu assets carry their own licences, included alongside them
under `.config/retroarch/assets`.
