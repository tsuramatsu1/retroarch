#!/usr/bin/env bash
#
# WonderSwan and WonderSwan Color (Beetle Cygne).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=mednafen_wswan
REPO=libretro/beetle-wswan-libretro

build_libretro_core || exit 1
