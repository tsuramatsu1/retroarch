#!/usr/bin/env bash
#
# Virtual Boy (Beetle VB).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=mednafen_vb
REPO=libretro/beetle-vb-libretro

build_libretro_core || exit 1
