#!/bin/bash

# ARM64 Linux cross-compilation configuration
# Prerequisites:
#   Arch: sudo pacman -S aarch64-linux-gnu-gcc
#   Ubuntu/Debian: sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
#
# Note: You'll need ARM64 versions of all enabled libraries.
# Either cross-compile them or use a sysroot.

./configure \
  --arch=aarch64 \
  --target-os=linux \
  --enable-cross-compile \
  --cross-prefix=aarch64-linux-gnu- \
  --cc=aarch64-linux-gnu-gcc \
  --cxx=aarch64-linux-gnu-g++ \
  --prefix=/opt/ffmpeg \
  --extra-version=tessus \
  --enable-gpl \
  --enable-version3 \
  --enable-nonfree \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libopus \
  --enable-libmp3lame \
  --enable-libvorbis \
  --enable-libtheora \
  --enable-libopenjpeg \
  --enable-libvidstab \
  --enable-libaom \
  --enable-libsvtav1 \
  --enable-librav1e \
  --enable-libdav1d \
  --enable-libfdk-aac \
  --enable-libzimg \
  --enable-librubberband \
  --enable-libsrt \
  --enable-libssh \
  --enable-libxml2 \
  --enable-libfreetype \
  --enable-libfontconfig \
  --enable-libfribidi \
  --enable-libass \
  --enable-libharfbuzz \
  --enable-libwebp \
  --enable-libopencore-amrnb \
  --enable-libopencore-amrwb \
  --enable-libvo-amrwbenc \
  --enable-libspeex \
  --enable-libsoxr \
  --enable-vulkan \
  --enable-opencl \
  --enable-libshaderc \
  --enable-libplacebo \
  --enable-libzmq \
  --enable-libbluray \
  --enable-libcdio \
  --enable-chromaprint \
  --enable-openal \
  --enable-libpulse \
  --enable-alsa \
  --enable-libgme \
  --enable-libsnappy \
  --enable-libaribcaption \
  --enable-libkvazaar \
  --enable-libopenh264 \
  --enable-libmysofa \
  --enable-libbs2b \
  --enable-vapoursynth \
  --enable-libxvid \
  --enable-lv2 \
  --enable-librist \
  --enable-libtesseract \
  --enable-openssl \
  --enable-sdl2 \
  --enable-static \
  --enable-libnghttp2
