#!/usr/bin/env bash
#
# Cloud Agent install step for PokeTokenBar.
#
# PokeTokenBar is a macOS-only menu bar app: its sources import Apple-only
# frameworks (AppKit, SwiftUI, Security, ServiceManagement, QuartzCore,
# ImageIO, CryptoKit, ...) that do NOT exist in the open-source Swift
# toolchain on Linux. Building, testing, and running the app therefore require
# macOS + Xcode/Swift 6 (CI runs on `macos-15`; see .github/workflows/ci.yml).
#
# This script is OS-aware so the same .cursor/environment.json works whether
# the agent runs on the default Linux Cloud VM or on a macOS environment
# (a Namespace Devbox selected in the Cloud Agent UI, or a self-hosted Mac
# worker):
#
#   * macOS  -> verify the Swift 6 toolchain and build the app (`swift build`).
#   * Linux  -> install the Swift 6 toolchain for editing and Foundation-level
#               code. A full `swift build` is intentionally NOT attempted
#               because the macOS-only frameworks above cannot resolve.
#
# The script is idempotent: re-runs short-circuit when work is already done.
set -euo pipefail

SWIFT_VERSION="6.0.3"

log() { printf '==> %s\n' "$*"; }

install_macos() {
  log "macOS detected — verifying Swift toolchain"
  if ! command -v swift >/dev/null 2>&1; then
    cat >&2 <<'ERR'
✗ Swift toolchain not found on this macOS host.
  Install Xcode 16 (or the matching Swift 6 toolchain) and select it with
  `sudo xcode-select -s /Applications/Xcode.app`, then re-run install.
ERR
    exit 1
  fi
  swift --version

  # PokeTokenBar builds natively on macOS. A debug build both verifies the
  # environment and warms the build cache. There are no external SwiftPM
  # dependencies to resolve, so this is the meaningful readiness check.
  log "Building the app (swift build)"
  swift build

  log "macOS environment ready — 'swift test' / './scripts/test-gate.sh' are available."
}

install_linux() {
  local swiftly_env="$HOME/.local/share/swiftly/env.sh"

  # 1) System libraries required by the Swift toolchain on Ubuntu 24.04.
  log "Linux detected — installing Swift system dependencies (apt)"
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 \
    libgcc-13-dev libpython3-dev libstdc++-13-dev libxml2-dev libz3-dev \
    pkg-config tzdata unzip zlib1g-dev libncurses-dev

  # 2) Install swiftly (the official Swift toolchain manager) if absent.
  if [[ ! -f "$swiftly_env" ]]; then
    log "Installing swiftly"
    local arch tmp
    arch="$(uname -m)"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/swiftly.tar.gz" \
      "https://download.swift.org/swiftly/linux/swiftly-${arch}.tar.gz"
    tar -C "$tmp" -xzf "$tmp/swiftly.tar.gz"
    "$tmp/swiftly" init --quiet-shell-followup --assume-yes --skip-install
    rm -rf "$tmp"
  else
    log "swiftly already installed"
  fi

  # shellcheck disable=SC1090
  . "$swiftly_env"

  # 3) Install the pinned Swift toolchain if it is not already the default.
  if swift --version 2>/dev/null | grep -q "swift-${SWIFT_VERSION}"; then
    log "Swift ${SWIFT_VERSION} already installed"
  else
    # `swiftly install` sets this toolchain as the global default. Avoid
    # `swiftly use`, which would write a `.swift-version` file into the repo
    # working tree and add noise to `git status`.
    log "Installing Swift ${SWIFT_VERSION}"
    swiftly install "$SWIFT_VERSION" --assume-yes
  fi

  log "Swift toolchain ready:"
  swift --version

  cat <<'NOTE'

Note: PokeTokenBar is a macOS-only application. `swift build`, `swift test`,
and running the app require macOS + Xcode/Swift 6 and cannot be completed on
this Linux Cloud Agent. Use the toolchain above for editing and Foundation-
level checks; run the full build/test suite on macOS (CI: macos-15).
NOTE
}

os="$(uname -s)"
case "$os" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *)
    echo "✗ Unsupported OS for PokeTokenBar development: $os" >&2
    exit 1
    ;;
esac
