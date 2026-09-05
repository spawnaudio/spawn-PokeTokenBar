#!/bin/bash
# Rebuild the side-by-side "PokeTokenBar v2.0" app (2.5% economy, isolated save).
# Does not replace /Applications/PokeTokenBar.app.
#
#   ./scripts/rebuild-v2.sh                 # build current tree → v2.0
#   ./scripts/rebuild-v2.sh --pull-upstream # fetch+merge chattymin/PokeTokenBar, then build
set -euo pipefail
cd "$(dirname "$0")/.."

PULL=0
for arg in "$@"; do
    case "$arg" in
        --pull-upstream) PULL=1 ;;
        -h|--help)
            sed -n '2,8p' "$0"
            exit 0
            ;;
        *)
            echo "unknown arg: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

if [[ "$PULL" == "1" ]]; then
    echo "==> fetch+merge upstream/main (official PokeTokenBar)"
    git fetch upstream
    git merge --no-edit upstream/main
fi

if [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

export PTB_APP_NAME="PokeTokenBar v2.0"
export PTB_BUNDLE_ID="io.github.chattymin.poketokenbar.v2"
./scripts/build-app.sh
open "/Applications/PokeTokenBar v2.0.app"
echo "v2.0 save stays in ~/Library/Application Support/PokeTokenBar v2.0"
