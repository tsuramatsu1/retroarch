# RetroArch for jailbroken PS5

A ready-to-run RetroArch payload for a jailbroken PS5, with 13 libretro cores
already built for the console.

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
2. Copy this whole folder to `homebrew/RetroArch` on internal storage or a USB
   drive, so you end up with one of:

   ```
   /data/homebrew/RetroArch
   /mnt/usb0/homebrew/RetroArch      (usb0 through usb7)
   /mnt/ext0/homebrew/RetroArch      (ext0, ext1)
   ```

3. Open the Homebrew Launcher on the console and pick **RetroArch**.

BIOS files go in `.config/retroarch/system`

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

The `build-*.sh` scripts rebuild individual cores, and `build.sh` rebuilds the
frontend. They need the
[ps5-payload-dev/sdk](https://github.com/ps5-payload-dev/sdk) toolchain with
`PS5_PAYLOAD_SDK` set. `fetch-assets.sh` and `fetch-databases.sh` refresh the menu
assets and the game databases.
