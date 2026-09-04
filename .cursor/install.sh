#!/usr/bin/env bash
#
# Cloud Agent install step for PokeTokenBar.
#
# IMPORTANT: PokeTokenBar is a macOS-only menu bar app. It imports AppKit,
# SwiftUI, Security, ServiceManagement, QuartzCore, ImageIO, and other
# Apple-platform frameworks that do NOT exist in the open-source Swift
# toolchain on Linux. A full `swift build` / `swift test` therefore only
# works on macOS (CI runs on `macos-15`; see .github/workflows/ci.yml).
#
# On the Linux Cloud Agent this script installs the Swift 6 toolchain so the
# agent can read, navigate, and edit Swift sources and run Foundation-level
# Swift code. It deliberately does NOT attempt to build the app, because that
# is expected to fail on Linux.
#
# The script is idempotent: it is safe to re-run and short-circuits when the
# toolchain is already present.
set -euo pipefail

SWIFT_VERSION="6.0.3"
SWIFTLY_ENV="$HOME/.local/share/swiftly/env.sh"

log() { printf '==> %s\n' "$*"; }

# 1) System libraries required by the Swift toolchain on Ubuntu 24.04.
log "Installing Swift system dependencies (apt)"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq \
  binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 \
  libgcc-13-dev libpython3-dev libstdc++-13-dev libxml2-dev libz3-dev \
  pkg-config tzdata unzip zlib1g-dev libncurses-dev

# 2) Install swiftly (the official Swift toolchain manager) if absent.
if [[ ! -f "$SWIFTLY_ENV" ]]; then
  log "Installing swiftly"
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
. "$SWIFTLY_ENV"

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
