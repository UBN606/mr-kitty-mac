#!/bin/bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
compiler="$(xcrun --find swiftc 2>/dev/null || true)"
if [[ -z "$compiler" ]]; then
  echo "Apple Command Line Tools are required to compile this test build."
  echo "Run: xcode-select --install"
  exit 1
fi

bash "$here/build-mac.sh" "$HOME/Applications"
app="$HOME/Applications/Mr Kitty.app"
echo "Built: $app"
open "$app"
