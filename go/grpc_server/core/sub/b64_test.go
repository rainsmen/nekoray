package sub

import "testing"

// TestDecodeB64IfValidRejectsPlainText guards the regression where ordinary
// words made only of base64 characters ("password", "shadowsocks") were
// "decoded" into binary garbage and then parsed as subscription content.
func TestDecodeB64IfValidRejectsPlainText(t *testing.T) {
	plain := []string{
		"password",
		"shadowsocks",
		"hello world",       // space is outside the alphabet
		"vmess://abc",       // ':' and '/' mix
		"abc",               // too short to be meaningful
		"",
		"not@base64!",
	}
	for _, s := range plain {
		if got := decodeB64IfValid(s); got != "" {
			t.Errorf("decodeB64IfValid(%q) = %q, want \"\" (plain text must not decode)", s, got)
		}
	}
}

func TestDecodeB64IfValidDecodesRealBase64(t *testing.T) {
	cases := map[string]string{
		// "ss://example" in std and url-safe encodings
		"c3M6Ly9leGFtcGxl":     "ss://example",
		"c3M6Ly9leGFtcGxl==":   "ss://example",
		"aGVsbG8gd29ybGQ=":     "hello world",
	}
	for in, want := range cases {
		if got := decodeB64IfValid(in); got != want {
			t.Errorf("decodeB64IfValid(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestDecodeB64IfValidRejectsNonUTF8(t *testing.T) {
	// base64 of 0xff 0xfe 0xfd 0xfc — valid base64, invalid UTF-8.
	if got := decodeB64IfValid("//79/A=="); got != "" {
		t.Errorf("decodeB64IfValid decoded non-UTF-8 payload to %q", got)
	}
}

func TestDecodeB64IfValidRejectsOversizedInput(t *testing.T) {
	big := make([]byte, maxLinkLength+1)
	for i := range big {
		big[i] = 'A'
	}
	if got := decodeB64IfValid(string(big)); got != "" {
		t.Error("decodeB64IfValid accepted an input above maxLinkLength")
	}
}
