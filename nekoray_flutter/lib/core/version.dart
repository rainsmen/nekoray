// Single Dart-side source of app version metadata.
//
// Mirrors `nekoray_version.txt` and the pubspec version (enforced together by
// `libs/check_version.sh`) so UI strings never hardcode a stale version.
const appVersion = '5.0.1';
const singBoxVersion = '1.13.19';
