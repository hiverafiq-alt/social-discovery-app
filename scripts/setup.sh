#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -d /tmp/social-discovery-flutter ]; then
    git clone --depth 1 --branch 3.35.7 https://github.com/flutter/flutter.git /tmp/social-discovery-flutter
  fi
  export PATH="/tmp/social-discovery-flutter/bin:$PATH"
fi
flutter pub get --enforce-lockfile
