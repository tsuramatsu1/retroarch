#!/usr/bin/env bash
#
# 3DO (Opera). Needs a 3DO BIOS in .config/retroarch/system.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=opera
REPO=libretro/opera-libretro

build_libretro_core || exit 1
