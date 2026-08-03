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
URL="https://github.com/libretro/pcsx_rearmed/archive/refs/heads/master.tar.gz"
INFO="https://raw.githubusercontent.com/libretro/libretro-core-info/refs/heads/master/pcsx_rearmed_libretro.info"

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

wget -O $TEMPDIR/pcsx_rearmed.tar.gz "${URL}" || exit 1
tar xf  $TEMPDIR/pcsx_rearmed.tar.gz -C $TEMPDIR || exit 1

cd $TEMPDIR/pcsx_rearmed-$VER || exit 1

# rthreads.c pulls <sys/time.h> for CLOCK_REALTIME only when BSD/ORBIS/VITA is
# defined; without it clock_gettime() has no clock id on this target.
sed -i 's|^USE_ASYNC_CDROM ?= 1|&\nCFLAGS += -DBSD|' Makefile.libretro
grep -q 'CFLAGS += -DBSD' Makefile.libretro || { echo "error: failed to inject -DBSD"; exit 1; }

# the startup CPU feature check emits __cpu_model/__cpu_indicator_init, which are
# libgcc/compiler-rt symbols the SDK does not ship. They are data, so they must
# resolve when the module loads, and dlopen fails outright without them.
sed -i 's|^#define DO_CPU_CHECKS .*|#define DO_CPU_CHECKS 0|' frontend/main.c
grep -q '^#define DO_CPU_CHECKS 0' frontend/main.c || { echo "error: failed to disable DO_CPU_CHECKS"; exit 1; }

# the lightrec JIT allocator is hardcoded to Linux APIs (MAP_HUGETLB,
# MAP_HUGE_SHIFT, SYS_memfd_create), none of which exist in the BSD sysroot,
# so fall back to the interpreter as the macOS and iOS targets do.
#
# physical disc access needs the Linux SCSI ioctls, which leaves a dangling
# else in libretro-common's cdrom.c on a BSD target. Disc images are unaffected.
${MAKE} -f Makefile.libretro DYNAREC=0 HAVE_PHYSICAL_CDROM=0 || exit 1

mkdir -p "${ROOT_DIR}/.config/retroarch/cores" || exit 1
mv $TEMPDIR/pcsx_rearmed-$VER/pcsx_rearmed_libretro.so "${ROOT_DIR}/.config/retroarch/cores/" || exit 1
wget $INFO -O "${ROOT_DIR}/.config/retroarch/cores/pcsx_rearmed_libretro.info"
