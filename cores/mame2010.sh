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
URL="https://github.com/libretro/mame2010-libretro/archive/refs/heads/master.tar.gz"
INFO="https://raw.githubusercontent.com/libretro/libretro-core-info/refs/heads/master/mame2010_libretro.info"

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

wget -O $TEMPDIR/mame2010.tar.gz "${URL}" || exit 1
tar xf  $TEMPDIR/mame2010.tar.gz -C $TEMPDIR || exit 1

cd $TEMPDIR/mame2010-libretro-$VER || exit 1

# 2010-era C/C++ with heavy type punning; clang miscompiles it under strict
# aliasing, so drop the flag wherever the makefiles add it.
sed -i 's|-fstrict-aliasing|-fno-strict-aliasing|g' Makefile
grep -q '\-fno-strict-aliasing' Makefile || { echo "error: failed to disable strict aliasing"; exit 1; }

# these pin themselves to POSIX.1b (1993), which on a BSD sysroot hides the C99
# float math and CLOCK_REALTIME that the same files then use.
for f in $(grep -rl '^#define _POSIX_C_SOURCE 199309' . --include=*.c --include=*.cpp 2>/dev/null); do
    sed -i 's|^#define _POSIX_C_SOURCE 199309.*|/* removed: hides C99 math and CLOCK_REALTIME on a BSD sysroot */|' "$f"
done

# state.h picks <tr1/type_traits> for any __GNUC__ compiler, which clang defines
# but libc++ never shipped. Use the plain C++11 header and namespace, matching
# the branch the file already takes on macOS.
sed -i 's|#include <tr1/type_traits>|#include <type_traits>|' src/emu/state.h
sed -i 's|#define DEF_NAMESPACE std::tr1|#define DEF_NAMESPACE std|g' src/emu/state.h
grep -q 'tr1' src/emu/state.h && { echo "error: tr1 reference still in state.h"; exit 1; }

# The m68000 recipes are the only ones using $(CC). Upstream relies on CC being
# g++ there, but prospero.sh exports a C compiler and CC ?= loses to the
# environment, so emucore.h's C++ includes go missing. There are four copies of
# this rule across the two included makefiles and make honours the last one, so
# all of them have to change.
sed -i '/m68000 -c /s|$(CC)|$(CXX)|' Makefile.common Makefile.tiny
if grep -h 'm68000 -c ' Makefile.common Makefile.tiny | grep -q '\$(CC)'; then
    echo "error: an m68000 recipe still uses \$(CC)"
    exit 1
fi

# The OSD layer assumes Linux. SDLMAME_NO64BITIO picks the plain stat/readdir
# typedefs over the LFS64 ones (Android and iOS already pass it), and
# NO_AFFINITY_NP stubs out the cpu_set_t/pthread_setaffinity_np path.
sed -i 's|^DEFS += -DNDEBUG|DEFS += -DNDEBUG -DSDLMAME_NO64BITIO -DNO_AFFINITY_NP|' Makefile
grep -q 'DSDLMAME_NO64BITIO -DNO_AFFINITY_NP' Makefile || {
    echo "error: failed to add the OSD defines"
    exit 1
}

# retrofile.c calls the LFS64 entry points directly rather than going through a
# typedef, and on this sysroot the plain names are already 64-bit.
sed -i 's|\bopen64(|open(|g; s|\bpread64(|pread(|g; s|\bpwrite64(|pwrite(|g; s|\blseek64(|lseek(|g; s|\bftruncate64(|ftruncate(|g' src/osd/retro/retrofile.c
if grep -qE '\b(open|pread|pwrite|lseek|ftruncate)64\(' src/osd/retro/retrofile.c; then
    echo "error: an LFS64 call remains in retrofile.c"
    exit 1
fi

# the toolchain provides libc++, which clang++ links on its own; there is no
# libstdc++ to find.
sed -i 's|^\([[:space:]]*LIBS += \)-lstdc++ |\1|' Makefile
if grep -qE '^[[:space:]]*LIBS \+= -lstdc\+\+' Makefile; then
    echo "error: -lstdc++ still in LIBS"
    exit 1
fi

# FORCE_DRC_C_BACKEND uses the portable C recompiler instead of emitting native
# code at runtime, which the payload sandbox will not let us map executable.
# NOWERROR because clang 18 raises warnings this tree was never built against.
# BUILD_ZLIB compiles the bundled zlib into libz.a; the sysroot has no libz, and
# a stub is not an option because zlib is what reads the romset archives.
${MAKE} FORCE_DRC_C_BACKEND=1 NOWERROR=1 BUILD_ZLIB=1 || exit 1

mkdir -p "${ROOT_DIR}/.config/retroarch/cores" || exit 1
mv $TEMPDIR/mame2010-libretro-$VER/mame2010_libretro.so "${ROOT_DIR}/.config/retroarch/cores/" || exit 1
wget $INFO -O "${ROOT_DIR}/.config/retroarch/cores/mame2010_libretro.info"
