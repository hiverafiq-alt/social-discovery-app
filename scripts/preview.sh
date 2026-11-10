#!/usr/bin/env bash
set -euo pipefail
export PATH="/tmp/social-discovery-flutter/bin:$PATH"
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8080 --dart-define=DEMO_MODE=true --dart-define=WEB_PREVIEW=true
