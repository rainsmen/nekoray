package grpc_server

import "testing"

func TestCompareVersions(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{
		{"5.0.0", "5.0.0", 0},
		{"5.0.1", "5.0.0", 1},
		{"5.0.0", "5.0.1", -1},
		{"5.1.0", "5.0.9", 1},
		{"6.0.0", "5.9.9", 1},
		// A pre-release sorts before the matching final release. This is the
		// case the old strings.Contains check got wrong: "5.0.0" is contained
		// in "5.0.0-beta.3", so an upgrade was reported as "already current".
		{"5.0.0-beta.3", "5.0.0", -1},
		{"5.0.0", "5.0.0-beta.3", 1},
		{"5.0.0-beta.3", "5.0.0-beta.2", 1},
		{"5.0.0-beta.2", "5.0.0-beta.10", -1},
		{"5.0", "5.0.0", 0},
	}
	for _, c := range cases {
		if got := compareVersions(c.a, c.b); got != c.want {
			t.Errorf("compareVersions(%q, %q) = %d, want %d", c.a, c.b, got, c.want)
		}
	}
}

func TestValidateUpdateURL(t *testing.T) {
	ok := []string{
		"https://github.com/rainsmen/nekoray/releases/download/v5/nekoray-linux64.tar.gz",
		"https://objects.githubusercontent.com/blob/abc",
	}
	for _, u := range ok {
		if err := validateUpdateURL(u); err != nil {
			t.Errorf("validateUpdateURL(%q) rejected a valid URL: %v", u, err)
		}
	}

	bad := []string{
		"http://github.com/x",            // plaintext
		"https://evil.example.com/x.zip", // wrong host
		"file:///etc/passwd",
		"https://github.com.evil.com/x",
		"",
	}
	for _, u := range bad {
		if err := validateUpdateURL(u); err == nil {
			t.Errorf("validateUpdateURL(%q) accepted an unsafe URL", u)
		}
	}
}

func TestFindChecksumAsset(t *testing.T) {
	assets := []ghAsset{
		{Name: "nekoray-5.0.0-linux64.tar.gz", BrowserDownloadUrl: "https://x/a"},
		{Name: "SHA256SUMS.txt", BrowserDownloadUrl: "https://x/sums"},
	}
	if got := findChecksumAsset(assets); got != "https://x/sums" {
		t.Errorf("findChecksumAsset = %q, want the checksums asset", got)
	}
	if got := findChecksumAsset(assets[:1]); got != "" {
		t.Errorf("findChecksumAsset = %q, want empty when no checksums published", got)
	}
}
