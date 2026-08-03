# RetroArch for jailbroken PS5

Build recipes for a RetroArch payload for a jailbroken PS5, with 33 libretro
cores.

The PS5 port of RetroArch itself is **john-tornblom's**, distributed as part of
[ps5-payload-dev/websrv](https://github.com/ps5-payload-dev/websrv). This
repository is that port plus extra cores; all of the porting work is his.

## Systems included

| Core | System |
|---|---|
| `fceumm` | NES / Famicom |
| `nestopia` | NES / Famicom (more accurate, heavier) |
| `snes9x` | SNES |
| `snes9x2010` | SNES (older, lighter fork) |
| `gambatte` | Game Boy / Game Boy Color |
| `mgba` | Game Boy / Game Boy Color / Game Boy Advance |
| `mednafen_gba` | Game Boy Advance |
| `desmume2015` | Nintendo DS |
| `parallel_n64` | Nintendo 64 |
| `genesis_plus_gx` | Mega Drive / Master System / Game Gear |
| `picodrive` | Mega Drive / Sega CD / 32X / Master System / Game Gear |
| `yabause` | Sega Saturn |
| `mednafen_pce_fast` | PC Engine / TurboGrafx-16 / PCE-CD |
| `mednafen_psx` | PlayStation |
| `pcsx_rearmed` | PlayStation (faster) |
| `opera` | 3DO |
| `mednafen_vb` | Virtual Boy |
| `mednafen_wswan` | WonderSwan / WonderSwan Color |
| `mednafen_ngp` | Neo Geo Pocket / Color |
| `stella2023` | Atari 2600 |
| `prosystem` | Atari 7800 |
| `handy` | Atari Lynx |
| `virtualjaguar` | Atari Jaguar |
| `mame2003_plus` | Arcade |
| `mame2010` | Arcade (newer romsets) |
| `fbneo` | Arcade (FinalBurn Neo) |
| `fbalpha2012_cps1` | Arcade - Capcom CPS-1 |
| `fbalpha2012_cps2` | Arcade - Capcom CPS-2 |
| `fbalpha2012_neogeo` | Arcade - Neo Geo |
| `puae` / `puae2021` | Amiga |
| `vice_x64` | Commodore 64 |
| `dosbox_pure` | MS-DOS / PC |

## Install

1. Make sure `websrv` is running.
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
| `build-core-common.sh` | shared fetch/build/verify plumbing the newer core recipes source |
| `fetch-assets.sh`, `fetch-databases.sh` | menu assets and game databases |

Each core lands in `.config/retroarch/cores` next to its `.info` file. The
recipes that source `build-core-common.sh` refuse to stage a core unless it
exports the libretro entry points in its **dynamic** symbol table, imports
`libkernel_web.sprx` (proof the Prospero toolchain was used and not the host
compiler), does not import `libkernel_sys.sprx` (absent from websrv's process,
and a module that wants it fails to load with nothing shown on screen), and does
not declare `hw_render`.

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
| `fceumm`, `nestopia`, `gambatte`, `mednafen_gba`, `mednafen_psx`, `mednafen_pce_fast`, `mednafen_vb`, `mednafen_wswan`, `mednafen_ngp`, `pcsx_rearmed`, `desmume2015`, `parallel_n64`, `yabause`, `stella2023`, `prosystem`, `puae`, `puae2021`, `vice_x64`, `dosbox_pure` | GPLv2 |
| `virtualjaguar` | GPLv3 |
| `mgba` | MPL 2.0 |
| `handy` | Zlib |
| `opera` | LGPL / non-commercial |
| `genesis_plus_gx`, `snes9x`, `snes9x2010`, `fbneo`, `fbalpha2012_cps1`, `fbalpha2012_cps2`, `fbalpha2012_neogeo` | Non-commercial |
| `mame2003_plus`, `mame2010`, `picodrive` | MAME licence (non-commercial) |

No binaries are committed to this repository, but **the release zip does contain
them**, so those terms apply to the releases: the non-commercial cores may not be
redistributed commercially, and MAME's licence has its own conditions. The GPLv2
cores are built from the upstream sources named in each `build-*.sh`, which serve
as the corresponding source.

Bundled fonts and menu assets carry their own licences, included alongside them
under `.config/retroarch/assets`.
