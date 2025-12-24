#!/bin/bash
#
# FFmpeg ARM64 Cross-Compilation Build Script
#
# This script builds FFmpeg for ARM64 using cross-compilation on x86_64.
# It's much faster than QEMU emulation because:
#   - Stage 1 (ARM64/QEMU): Only installs packages and creates sysroot (~5-10 min)
#   - Stage 2 (x86_64 native): Cross-compiles FFmpeg at full speed (~10-15 min)
#
# Prerequisites:
#   - Docker installed
#   - QEMU binfmt support for ARM64 (will be set up automatically)
#
# Usage:
#   ./build-arm64-cross.sh [--skip-sysroot] [--clean]
#
# Options:
#   --skip-sysroot  Skip rebuilding the sysroot (use cached version)
#   --clean         Remove all cached images and sysroot before building
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CROSS_BUILD_DIR="${SCRIPT_DIR}/cross-build"
SYSROOT_TAR="${CROSS_BUILD_DIR}/sysroot-arm64.tar.gz"
OUTPUT_DIR="${SCRIPT_DIR}/build-arm64"

# Parse arguments
SKIP_SYSROOT=false
CLEAN=false

for arg in "$@"; do
    case $arg in
        --skip-sysroot)
            SKIP_SYSROOT=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --help|-h)
            head -25 "$0" | tail -20
            exit 0
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Clean if requested
if [ "$CLEAN" = true ]; then
    log_info "Cleaning cached images and sysroot..."
    docker rmi ffmpeg-arm64-sysroot 2>/dev/null || true
    docker rmi ffmpeg-cross-compile 2>/dev/null || true
    rm -f "${SYSROOT_TAR}"
    rm -rf "${OUTPUT_DIR}"
    log_success "Clean complete"
fi

# Check for required files
if [ ! -f "${CROSS_BUILD_DIR}/Dockerfile.arm64-sysroot" ]; then
    log_error "Missing ${CROSS_BUILD_DIR}/Dockerfile.arm64-sysroot"
    exit 1
fi

if [ ! -f "${CROSS_BUILD_DIR}/Dockerfile.cross-compile" ]; then
    log_error "Missing ${CROSS_BUILD_DIR}/Dockerfile.cross-compile"
    exit 1
fi

# Ensure QEMU binfmt is set up for ARM64
log_info "Checking QEMU binfmt support for ARM64..."
if ! docker run --rm --platform linux/arm64 alpine uname -m 2>/dev/null | grep -q aarch64; then
    log_warn "Setting up QEMU binfmt support..."
    docker run --privileged --rm tonistiigi/binfmt --install arm64
    log_success "QEMU binfmt support installed"
else
    log_success "QEMU binfmt support already available"
fi

# ============================================================================
# Stage 1: Build ARM64 sysroot (runs under QEMU emulation)
# ============================================================================

if [ "$SKIP_SYSROOT" = true ] && [ -f "${SYSROOT_TAR}" ]; then
    log_info "Skipping sysroot build (using cached: ${SYSROOT_TAR})"
else
    log_info "============================================"
    log_info "Stage 1: Building ARM64 sysroot"
    log_info "============================================"
    log_info "This stage runs under QEMU emulation to install ARM64 packages."
    log_info "It may take 5-10 minutes..."
    echo ""

    # Build the sysroot Docker image
    log_info "Building ARM64 sysroot Docker image..."
    docker build --platform linux/arm64 \
        -t ffmpeg-arm64-sysroot \
        -f "${CROSS_BUILD_DIR}/Dockerfile.arm64-sysroot" \
        "${CROSS_BUILD_DIR}"

    # Extract the sysroot
    log_info "Extracting sysroot tarball..."
    mkdir -p "${CROSS_BUILD_DIR}"
    docker run --rm --platform linux/arm64 \
        -v "${CROSS_BUILD_DIR}:/output" \
        ffmpeg-arm64-sysroot

    if [ -f "${SYSROOT_TAR}" ]; then
        log_success "Sysroot created: ${SYSROOT_TAR}"
        ls -lh "${SYSROOT_TAR}"
    else
        log_error "Failed to create sysroot tarball"
        exit 1
    fi
fi

# ============================================================================
# Stage 2: Cross-compile FFmpeg (runs natively on x86_64)
# ============================================================================

log_info "============================================"
log_info "Stage 2: Cross-compiling FFmpeg"
log_info "============================================"
log_info "This stage runs natively on x86_64 for maximum speed."
echo ""

# Build the cross-compile Docker image
log_info "Building cross-compilation Docker image..."
docker build \
    -t ffmpeg-cross-compile \
    -f "${CROSS_BUILD_DIR}/Dockerfile.cross-compile" \
    "${CROSS_BUILD_DIR}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Prepare sysroot extraction directory
SYSROOT_EXTRACT_DIR="${CROSS_BUILD_DIR}/sysroot-extracted"
rm -rf "${SYSROOT_EXTRACT_DIR}"
mkdir -p "${SYSROOT_EXTRACT_DIR}"

log_info "Extracting sysroot for cross-compilation..."
tar -xzf "${SYSROOT_TAR}" -C "${SYSROOT_EXTRACT_DIR}"

# Run cross-compilation
log_info "Starting cross-compilation..."
docker run --rm \
    -v "${SCRIPT_DIR}:/ffmpeg:ro" \
    -v "${SYSROOT_EXTRACT_DIR}:/sysroot-arm64:ro" \
    -v "${OUTPUT_DIR}:/output" \
    -w /ffmpeg \
    ffmpeg-cross-compile \
    bash -c '
        # Copy source to writable location
        cp -r /ffmpeg /build-ffmpeg
        cd /build-ffmpeg
        /cross-compile.sh
    '

# Verify output
if [ -f "${OUTPUT_DIR}/opt/ffmpeg/bin/ffmpeg" ]; then
    log_success "============================================"
    log_success "Build completed successfully!"
    log_success "============================================"
    echo ""
    echo "ARM64 binaries are located at:"
    echo "  ${OUTPUT_DIR}/opt/ffmpeg/bin/"
    echo ""
    echo "Files:"
    ls -lh "${OUTPUT_DIR}/opt/ffmpeg/bin/"
    echo ""
    echo "To verify the binary architecture:"
    echo "  file ${OUTPUT_DIR}/opt/ffmpeg/bin/ffmpeg"
else
    log_error "Build failed - ffmpeg binary not found"
    exit 1
fi

# Cleanup extracted sysroot (keep the tarball for future builds)
log_info "Cleaning up temporary files..."
rm -rf "${SYSROOT_EXTRACT_DIR}"

log_success "Done! Use --skip-sysroot on subsequent builds to reuse the cached sysroot."
