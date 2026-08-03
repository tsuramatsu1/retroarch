#!/usr/bin/env bash
#
# Atari 7800 (ProSystem).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=prosystem
REPO=libretro/prosystem-libretro

build_libretro_core || exit 1
