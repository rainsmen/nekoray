//go:build android && with_purego

// Compile-time guard: the Android core must NOT be built with `with_purego`.
// sing-box's NaiveProxy outbound needs the Cronet native engine, and on
// Android the only supported mode is CGO + NDK (libcronet.a statically
// linked). With `with_purego`, the core would try to dlopen libcronet.so at
// runtime and every naive node would fail with "cronet: library not found".
// See libs/build_android.sh.
package main

// Undefined on purpose: breaks the build if this tag combo is ever used.
var _ = androidMustNotUsePuregoNaiveNeedsCGOCronet
