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
URL="https://github.com/libretro/desmume2015/archive/refs/heads/master.tar.gz"
INFO="https://raw.githubusercontent.com/libretro/libretro-core-info/refs/heads/master/desmume2015_libretro.info"

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

wget -O $TEMPDIR/desmume2015.tar.gz "${URL}" || exit 1
tar xf  $TEMPDIR/desmume2015.tar.gz -C $TEMPDIR || exit 1

cd $TEMPDIR/desmume2015-$VER/desmume || exit 1

# these two pin themselves to POSIX.1b (1993), which on a BSD sysroot drops
# __ISO_C_VISIBLE to 1990 and hides both the C99 float math used by
# retro_miscellaneous.h and the CLOCK_REALTIME they then go on to use.
POSIX_SRC="src/libretro-common/rthreads/rthreads.c src/libretro-common/rthreads/rsemaphore.c"
sed -i 's|^#define _POSIX_C_SOURCE 199309.*|/* removed: hides C99 math and CLOCK_REALTIME on a BSD sysroot */|' $POSIX_SRC
if grep -q '^#define _POSIX_C_SOURCE' $POSIX_SRC; then
    echo "error: failed to strip _POSIX_C_SOURCE"
    exit 1
fi

# DESMUME_JIT defaults to 1 on x86-64. The recompiler maps executable pages,
# which the payload sandbox does not permit, so use the ARM interpreter.
${MAKE} -f Makefile.libretro DESMUME_JIT=0 || exit 1

mkdir -p "${ROOT_DIR}/.config/retroarch/cores" || exit 1
mv $TEMPDIR/desmume2015-$VER/desmume/desmume2015_libretro.so "${ROOT_DIR}/.config/retroarch/cores/" || exit 1
wget $INFO -O "${ROOT_DIR}/.config/retroarch/cores/desmume2015_libretro.info"
