#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "No missing packages specified for source fallback." >&2
  exit 0
fi

PREFIX="${PREFIX:-$PWD/ffmpeg-static-deps}"
WORKDIR="${WORKDIR:-$PWD/.deps-build}"

mkdir -p "$PREFIX" "$WORKDIR"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib/aarch64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"
export CFLAGS="${CFLAGS:-} -fPIC"
export CXXFLAGS="${CXXFLAGS:-} -fPIC"
export PATH="$HOME/.local/bin:$PATH"

build_autotools() {
  local name="$1"
  local repo="$2"
  local dir="$WORKDIR/$name"

  rm -rf "$dir"
  git clone --depth 1 "$repo" "$dir"
  pushd "$dir" >/dev/null
  if [[ -x ./autogen.sh ]]; then
    ./autogen.sh
  else
    autoreconf -fiv
  fi
  ./configure --prefix="$PREFIX" --enable-static --disable-shared
  make -j"$(nproc)"
  make install
  popd >/dev/null
}

build_meson() {
  local name="$1"
  local repo="$2"
  local dir="$WORKDIR/$name"

  rm -rf "$dir"
  git clone --depth 1 "$repo" "$dir"
  pushd "$dir" >/dev/null
  meson setup build --prefix="$PREFIX" --buildtype=release -Ddefault_library=static
  ninja -C build
  ninja -C build install
  popd >/dev/null
}

build_cmake() {
  local name="$1"
  local repo="$2"
  shift 2
  local dir="$WORKDIR/$name"

  rm -rf "$dir"
  git clone --depth 1 "$repo" "$dir"
  pushd "$dir" >/dev/null
  cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF "$@"
  cmake --build build -j"$(nproc)"
  cmake --install build
  popd >/dev/null
}

build_make() {
  local name="$1"
  local repo="$2"
  local dir="$WORKDIR/$name"

  rm -rf "$dir"
  git clone --depth 1 "$repo" "$dir"
  pushd "$dir" >/dev/null
  make -j"$(nproc)"
  make install PREFIX="$PREFIX" STATIC=1
  popd >/dev/null
}

for pkg in "$@"; do
  case "$pkg" in
    cython|cython3|python3-cython)
      python3 -m pip install --user --no-cache-dir --break-system-packages cython
      ;;
    libaribcaption-dev)
      build_cmake "libaribcaption" "https://github.com/xqq/libaribcaption.git"
      ;;
    libfdk-aac-dev)
      build_autotools "fdk-aac" "https://github.com/mstorsjo/fdk-aac.git"
      ;;
    libkvazaar-dev)
      build_autotools "kvazaar" "https://github.com/ultravideo/kvazaar.git"
      ;;
    libopenh264-dev)
      build_make "openh264" "https://github.com/cisco/openh264.git"
      ;;
    librist-dev)
      build_meson "librist" "https://code.videolan.org/rist/librist.git"
      ;;
    libvpl-dev)
      build_cmake "oneVPL" "https://github.com/oneapi-src/oneVPL.git"
      ;;
    libchromaprint-dev)
      build_cmake "chromaprint" "https://github.com/acoustid/chromaprint.git" -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF
      ;;
    libvapoursynth-dev)
      build_meson "vapoursynth" "https://github.com/vapoursynth/vapoursynth.git"
      ;;
    vapoursynth)
      build_meson "vapoursynth" "https://github.com/vapoursynth/vapoursynth.git"
      ;;
    *)
      echo "No source fallback defined for missing package: $pkg" >&2
      exit 1
      ;;
  esac
done
