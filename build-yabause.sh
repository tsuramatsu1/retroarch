#!/usr/bin/env bash
#
# Sega Saturn (Yabause). Software rendering only, so expect it to be slow;
# it is here because nothing else covers the Saturn without a GL context.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=yabause
REPO=libretro/yabause
MAKE_DIR=yabause/src/libretro

build_libretro_core || exit 1
