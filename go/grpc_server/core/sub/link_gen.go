package sub

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"

	nekokfmt "grpc_server/core/fmt"
)

// GenerateLink generates a share link for the given profile entity.
// format: "nekoray", "v2rayn", "clash" (phase-1 MVP: v2rayn-style standard links).
func GenerateLink(ent *nekokfmt.ProxyEntity, format string) (string, error) {
	bean, err := ent.DecodeBean()
	if err != nil {
		return "", err
	}

	switch b := bean.(type) {
	case *nekokfmt.SocksHttpBean:
		return genSocksHTTPLink(b)
	case *nekokfmt.VMessBean:
		return genVMessLink(b, format)
	case *nekokfmt.TrojanVLESSBean:
		return genTrojanVLESSLink(b)
	case *nekokfmt.ShadowSocksBean:
		return genShadowsocksLink(b)
	case *nekokfmt.QUICBean:
		return genQUICLink(b)
	default:
		return "", fmt.Errorf("unsupported bean type for link generation")
	}
}

func genSocksHTTPLink(b *nekokfmt.SocksHttpBean) string {
	u := &url.URL{}
	if b.SocksHttpType == nekokfmt.SocksHttpTypeHTTP {
		if b.Stream != nil && b.Stream.Security == "tls" {
			u.Scheme = "https"
		} else {
			u.Scheme = "http"
		}
	} else {
		u.Scheme = "socks" + strconv.Itoa(b.SocksHttpType)
	}
	if b.Name != "" {
		u.Fragment = b.Name
	}
	if b.Username != "" {
		if b.Password != "" {
			u.User = url.UserPassword(b.Username, b.Password)
		} else {
			u.User = url.User(b.Username)
		}
	}
	u.Host = joinHostPort(b.ServerAddress, b.ServerPort)
	return u.String()
}

func genTrojanVLESSLink(b *nekokfmt.TrojanVLESSBean) string {
	u := &url.URL{}
	q := url.Values{}
	if b.ProxyType == nekokfmt.TrojanVLESSProxyVLESS {
		u.Scheme = "vless"
	} else {
		u.Scheme = "trojan"
	}
	u.User = url.User(b.Password)
	u.Host = joinHostPort(b.ServerAddress, b.ServerPort)
	if b.Name != "" {
		u.Fragment = b.Name
	}

	if b.Stream == nil {
		b.Stream = &nekokfmt.V2RayStreamSettings{}
	}
	// security
	security := b.Stream.Security
	if security == "tls" && strings.TrimSpace(b.Stream.RealityPbk) != "" {
		security = "reality"
	}
	q.Set("security", security)
	if b.Stream.Sni != "" {
		q.Set("sni", b.Stream.Sni)
	}
	if b.Stream.Alpn != "" {
		q.Set("alpn", b.Stream.Alpn)
	}
	if b.Stream.AllowInsecure {
		q.Set("allowInsecure", "1")
	}
	if b.Stream.UtlsFingerprint != "" {
		q.Set("fp", b.Stream.UtlsFingerprint)
	}
	if security == "reality" {
		q.Set("pbk", b.Stream.RealityPbk)
		if b.Stream.RealitySid != "" {
			q.Set("sid", b.Stream.RealitySid)
		}
		if b.Stream.RealitySpx != "" {
			q.Set("spx", b.Stream.RealitySpx)
		}
	}
	// type
	q.Set("type", b.Stream.Network)
	switch b.Stream.Network {
	case "ws", "http", "httpupgrade":
		if b.Stream.Path != "" {
			q.Set("path", b.Stream.Path)
		}
		if b.Stream.Host != "" {
			q.Set("host", b.Stream.Host)
		}
	case "grpc":
		if b.Stream.Path != "" {
			q.Set("serviceName", b.Stream.Path)
		}
	case "tcp":
		if b.Stream.HeaderType == "http" {
			if b.Stream.Path != "" {
				q.Set("path", b.Stream.Path)
			}
			q.Set("headerType", "http")
			q.Set("host", b.Stream.Host)
		}
	}
	if b.ProxyType == nekokfmt.TrojanVLESSProxyVLESS {
		if b.Flow != "" {
			q.Set("flow", b.Flow)
		}
		q.Set("encryption", "none")
	}
	u.RawQuery = q.Encode()
	return u.String()
}

func genShadowsocksLink(b *nekokfmt.ShadowSocksBean) string {
	u := &url.URL{Scheme: "ss"}
	if strings.HasPrefix(b.Method, "2022-") {
		u.User = url.UserPassword(b.Method, b.Password)
	} else {
		mp := b.Method + ":" + b.Password
		u.User = url.User(base64.URLEncoding.EncodeToString([]byte(mp)))
	}
	u.Host = joinHostPort(b.ServerAddress, b.ServerPort)
	if b.Name != "" {
		u.Fragment = b.Name
	}
	q := url.Values{}
	if b.Plugin != "" {
		q.Set("plugin", b.Plugin)
	}
	u.RawQuery = q.Encode()
	return u.String()
}

func genVMessLink(b *nekokfmt.VMessBean, format string) string {
	if b.Stream == nil {
		b.Stream = &nekokfmt.V2RayStreamSettings{}
	}
	// v2rayN JSON format
	obj := map[string]interface{}{
		"v":    "2",
		"ps":   b.Name,
		"add":  b.ServerAddress,
		"port": strconv.Itoa(b.ServerPort),
		"id":   b.Uuid,
		"aid":  strconv.Itoa(b.Aid),
		"net":  b.Stream.Network,
		"host": b.Stream.Host,
		"path": b.Stream.Path,
		"type": b.Stream.HeaderType,
		"scy":  b.Security,
	}
	if b.Stream.Security == "tls" {
		obj["tls"] = "tls"
	} else {
		obj["tls"] = ""
	}
	obj["sni"] = b.Stream.Sni
	js, _ := json.Marshal(obj)
	return "vmess://" + base64.StdEncoding.EncodeToString(js)
}

func genQUICLink(b *nekokfmt.QUICBean) string {
	u := &url.URL{}
	q := url.Values{}
	if b.ProxyType == nekokfmt.QUICProxyHysteria2 {
		u.Scheme = "hysteria2"
		if b.Password != "" {
			u.User = url.User(b.Password)
		}
		u.Host = joinHostPort(b.ServerAddress, b.ServerPort)
		if b.Sni != "" {
			q.Set("sni", b.Sni)
		}
		if b.HopPort != "" {
			q.Set("mport", b.HopPort)
		}
		if b.ObfsPassword != "" {
			q.Set("obfs-password", b.ObfsPassword)
		}
		if b.AllowInsecure {
			q.Set("insecure", "1")
		}
	} else { // tuic
		u.Scheme = "tuic"
		if b.Password != "" {
			u.User = url.UserPassword(b.Uuid, b.Password)
		} else {
			u.User = url.User(b.Uuid)
		}
		u.Host = joinHostPort(b.ServerAddress, b.ServerPort)
		if b.Sni != "" {
			q.Set("sni", b.Sni)
		}
		if b.CongestionControl != "" {
			q.Set("congestion_control", b.CongestionControl)
		}
		if b.Alpn != "" {
			q.Set("alpn", b.Alpn)
		}
		if b.UdpRelayMode != "" {
			q.Set("udp_relay_mode", b.UdpRelayMode)
		}
		if b.AllowInsecure {
			q.Set("allow_insecure", "1")
		}
		if b.DisableSni {
			q.Set("disable_sni", "1")
		}
	}
	if b.Name != "" {
		u.Fragment = b.Name
	}
	u.RawQuery = q.Encode()
	return u.String()
}

func joinHostPort(host string, port int) string {
	if strings.Contains(host, ":") && !strings.HasPrefix(host, "[") {
		return "[" + host + "]:" + strconv.Itoa(port)
	}
	return host + ":" + strconv.Itoa(port)
}

// --- SIP008 ---

// SIP008Server represents a server in a SIP008 subscription.
type SIP008Server struct {
	ID         int    `json:"id"`
	Remarks    string `json:"remarks"`
	Server     string `json:"server"`
	ServerPort int    `json:"server_port"`
	Method     string `json:"method"`
	Password   string `json:"password"`
	Plugin     string `json:"plugin"`
	PluginOpts string `json:"plugin_opts"`
}

// parseSIP008 parses SIP008 JSON subscription (Shadowsocks subscription format).
func parseSIP008(content string) []ParseResult {
	var doc struct {
		Servers []SIP008Server `json:"servers"`
	}
	if err := json.Unmarshal([]byte(content), &doc); err != nil {
		return []ParseResult{{Error: "invalid sip008: " + err.Error()}}
	}
	var results []ParseResult
	for _, s := range doc.Servers {
		bean := &nekokfmt.ShadowSocksBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          s.Remarks,
				ServerAddress: s.Server,
				ServerPort:    s.ServerPort,
			},
			Method:   s.Method,
			Password: s.Password,
			Plugin:   s.Plugin,
			Stream:   &nekokfmt.V2RayStreamSettings{Network: "tcp"},
		}
		if s.PluginOpts != "" {
			bean.Plugin = s.Plugin + ";" + s.PluginOpts
		}
		results = append(results, ParseResult{Profile: newEntity("shadowsocks", bean)})
	}
	return results
}
