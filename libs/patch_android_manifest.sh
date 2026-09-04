#!/usr/bin/env bash
# Injects install-time network permissions into the generated Android manifest.
#
# The android/ platform directory is created fresh by `flutter create` in CI,
# whose release manifest does NOT grant INTERNET. Without it every socket()
# fails with EPERM and the in-process core cannot bind its loopback gRPC
# port ("socket: operation not permitted").
#
# Both permissions are install-time "normal" permissions: no runtime prompt.
# Idempotent — safe to run on every build.
set -euo pipefail

MANIFEST="${1:-nekoray_flutter/android/app/src/main/AndroidManifest.xml}"
[ -f "$MANIFEST" ] || {
	echo "::error::manifest not found: $MANIFEST (run flutter create first)"
	exit 1
}
python3 - "$MANIFEST" <<'EOF'
import sys

path = sys.argv[1]
s = open(path, encoding='utf-8').read()
perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
]
missing = [p for p in perms if p not in s]
if not missing:
    print('permissions already present')
    sys.exit(0)
anchor = '<application'
assert anchor in s, 'no <application> tag found in manifest'
insert = ''.join(f'    <uses-permission android:name="{p}"/>\n' for p in missing)
s = s.replace(anchor, insert + anchor, 1)
open(path, 'w', encoding='utf-8').write(s)
print('injected:', ', '.join(missing))
EOF
grep -c "uses-permission" "$MANIFEST"
