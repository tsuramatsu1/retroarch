#!/usr/bin/env bash
#
# SNES (current Snes9x). snes9x2010 is the older, lighter fork of the same
# emulator and stays in the payload for slower content.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=snes9x
REPO=libretro/snes9x
MAKE_DIR=libretro

build_libretro_core || exit 1
