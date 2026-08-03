#!/usr/bin/env bash
#
# PC Engine / TurboGrafx-16 and PCE-CD (Beetle PCE Fast).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=mednafen_pce_fast
REPO=libretro/beetle-pce-fast-libretro

build_libretro_core || exit 1
