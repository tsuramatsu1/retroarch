#!/usr/bin/env bash
#   Copyright (C) 2025 John Törnblom
#
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING. If not see
# <http://www.gnu.org/licenses/>.

VER="master"
URL="https://github.com/libretro/mame2003-plus-libretro/archive/refs/heads/master.tar.gz"
INFO="https://raw.githubusercontent.com/libretro/libretro-core-info/refs/heads/master/mame2003_plus_libretro.info"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
# This script lives in cores/; the payload it stages into is one level up.
ROOT_DIR="$(dirname "$(dirname "${SCRIPT_PATH}")")"

if [[ -z "$PS5_PAYLOAD_SDK" ]]; then
    echo "error: PS5_PAYLOAD_SDK is not set"
    exit 1
fi

source "${PS5_PAYLOAD_SDK}/toolchain/prospero.sh" || exit 1

TEMPDIR=$(mktemp -d)
trap 'rm -rf -- "$TEMPDIR"' EXIT

wget -O $TEMPDIR/mame2003-plus-libretro.tar.gz "${URL}" || exit 1
tar xf  $TEMPDIR/mame2003-plus-libretro.tar.gz -C $TEMPDIR || exit 1

cd $TEMPDIR/mame2003-plus-libretro-$VER || exit 1

# _XOPEN_SOURCE=500 pins the BSD sysroot to pre-C99 visibility, hiding round()
# and the rest of the C99 math functions behind __ISO_C_VISIBLE >= 1999.
sed -i 's|-D_XOPEN_SOURCE=500|-D_XOPEN_SOURCE=700|g' Makefile

# the sysroot has no separate libm; the math functions live in libc.
sed -i 's|LIBS += -lm|LIBS +=|g' Makefile

# this is 2003-era C with pervasive type punning, and clang 18 miscompiles it
# under strict aliasing: the runtime-built core option array came out empty and
# the EEPROM handlers returned garbage.
sed -i 's|-fomit-frame-pointer -fstrict-aliasing|-fomit-frame-pointer -fno-strict-aliasing|' Makefile
grep -q '\-fno-strict-aliasing' Makefile || { echo "error: failed to disable strict aliasing"; exit 1; }

${MAKE} || exit 1

mkdir -p "${ROOT_DIR}/.config/retroarch/cores" || exit 1
mv $TEMPDIR/mame2003-plus-libretro-$VER/mame2003_plus_libretro.so "${ROOT_DIR}/.config/retroarch/cores/" || exit 1
wget $INFO -O "${ROOT_DIR}/.config/retroarch/cores/mame2003_plus_libretro.info"
