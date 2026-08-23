package grpc_server

import (
	"context"
	"encoding/json"
	"grpc_server/gen"
	"io"
	"net/http"
	"os"
	"runtime"
	"strings"
	"time"
)

var update_download_url string

// CurrentVersion is the version string used for update checking.
// It is set by the core on startup via SetVersion.
var CurrentVersion = "5.0.0"

// proxyHttpClient returns an HTTP client. When running through the core,
// the instance's proxy is used; otherwise a direct client is returned.
// This replaces the libneko neko_common.CreateProxyHttpClient helper.
var proxyHttpClient func() *http.Client = func() *http.Client {
	return &http.Client{Timeout: 30 * time.Second}
}

// SetProxyHttpClientFactory allows the core to inject a factory that
// routes requests through the running sing-box instance.
func SetProxyHttpClientFactory(f func() *http.Client) {
	proxyHttpClient = f
}

func (s *BaseServer) Update(ctx context.Context, in *gen.UpdateReq) (*gen.UpdateResp, error) {
	ret := &gen.UpdateResp{}
	client := proxyHttpClient()

	if in.Action == gen.UpdateAction_Check {
		ctx, cancel := context.WithTimeout(ctx, time.Second*10)
		defer cancel()

		req, _ := http.NewRequestWithContext(ctx, "GET",
			"https://api.github.com/repos/rainsmen/nekoray/releases", nil)
		resp, err := client.Do(req)
		if err != nil {
			ret.Error = err.Error()
			return ret, nil
		}
		defer resp.Body.Close()

		v := []struct {
			HtmlUrl   string `json:"html_url"`
			Assets    []struct {
				Name               string `json:"name"`
				BrowserDownloadUrl string `json:"browser_download_url"`
			} `json:"assets"`
			Prerelease bool   `json:"prerelease"`
			Body       string `json:"body"`
		}{}
		err = json.NewDecoder(resp.Body).Decode(&v)
		if err != nil {
			ret.Error = err.Error()
			return ret, nil
		}

		var search string
		switch {
		case runtime.GOOS == "windows" && runtime.GOARCH == "amd64":
			search = "windows64"
		case runtime.GOOS == "linux" && runtime.GOARCH == "amd64":
			search = "linux64"
		case runtime.GOOS == "darwin":
			search = "macos-" + runtime.GOARCH
		case runtime.GOOS == "android":
			search = "android-" + runtime.GOARCH
		default:
			ret.Error = "unsupported platform"
			return ret, nil
		}

		for _, release := range v {
			if len(release.Assets) > 0 {
				for _, asset := range release.Assets {
					if strings.Contains(asset.Name, CurrentVersion) {
						return ret, nil // No update needed
					}
					if strings.Contains(asset.Name, search) {
						if release.Prerelease && !in.CheckPreRelease {
							continue
						}
						update_download_url = asset.BrowserDownloadUrl
						ret.AssetsName = asset.Name
						ret.DownloadUrl = asset.BrowserDownloadUrl
						ret.ReleaseUrl = release.HtmlUrl
						ret.ReleaseNote = release.Body
						ret.IsPreRelease = release.Prerelease
						return ret, nil
					}
				}
			}
		}
	} else { // Download update
		if update_download_url == "" {
			ret.Error = "no download URL"
			return ret, nil
		}

		req, _ := http.NewRequestWithContext(ctx, "GET", update_download_url, nil)
		resp, err := client.Do(req)
		if err != nil {
			ret.Error = err.Error()
			return ret, nil
		}
		defer resp.Body.Close()

		f, err := os.OpenFile("../nekoray-update.zip", os.O_TRUNC|os.O_CREATE|os.O_RDWR, 0644)
		if err != nil {
			ret.Error = err.Error()
			return ret, nil
		}
		defer f.Close()

		_, err = io.Copy(f, resp.Body)
		if err != nil {
			ret.Error = err.Error()
			return ret, nil
		}
		f.Sync()
	}

	return ret, nil
}
