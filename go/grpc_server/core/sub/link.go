// Package sub implements subscription / share-link parsing and generation,
// mirroring the C++ fmt/Link2Bean.cpp + fmt/Bean2Link.cpp so subscription
// handling can run inside nekobox_core (phase 1 task 3 sink-down).
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

// ParseResult holds a parsed profile plus any error encountered.
type ParseResult struct {
	Profile *nekokfmt.ProxyEntity
	Error   string
}

// ParseContent parses subscription content of the given format.
// format: "auto", "raw", "clash", "sip008", "base64"
// For "auto", it tries base64 decode, then clash, then raw line-by-line.
func ParseContent(content, format string) []ParseResult {
	content = strings.TrimSpace(content)
	if content == "" {
		return nil
	}

	switch format {
	case "base64":
		return parseBase64(content)
	case "clash":
		return parseClash(content)
	case "sip008":
		return parseSIP008(content)
	case "raw":
		return parseRaw(content)
	default: // auto
		return parseAuto(content)
	}
}

func parseAuto(content string) []ParseResult {
	// 1. try base64 decode (whole content)
	if decoded, err := base64.StdEncoding.DecodeString(content); err == nil {
		s := strings.TrimSpace(string(decoded))
		if s != "" && s != content {
			// recursively parse decoded content as auto
			return parseAuto(s)
		}
	}
	// also try URL-safe base64
	if decoded, err := base64.URLEncoding.DecodeString(content); err == nil {
		s := strings.TrimSpace(string(decoded))
		if s != "" && s != content {
			return parseAuto(s)
		}
	}

	// 2. clash yaml
	if strings.Contains(content, "proxies:") {
		return parseClash(content)
	}

	// 3. multi-line raw
	if strings.Count(content, "\n") > 0 {
		return parseRaw(content)
	}

	// 4. single line
	return parseRaw(content)
}

// parseBase64 decodes base64 content then parses as auto.
func parseBase64(content string) []ParseResult {
	decoded, err := base64.StdEncoding.DecodeString(content)
	if err != nil {
		// try url-safe
		decoded, err = base64.URLEncoding.DecodeString(content)
		if err != nil {
			return []ParseResult{{Error: "invalid base64: " + err.Error()}}
		}
	}
	return parseAuto(strings.TrimSpace(string(decoded)))
}

// parseRaw parses raw link list (one link per line).
func parseRaw(content string) []ParseResult {
	var results []ParseResult
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		r := ParseLink(line)
		results = append(results, r)
	}
	return results
}

// ParseLink parses a single share link into a ProxyEntity.
// Supports: ss://, vmess://, vless://, trojan://, hysteria2://, hy2://,
// tuic://, socks://, http(s)://.
func ParseLink(link string) ParseResult {
	link = strings.TrimSpace(link)
	if link == "" {
		return ParseResult{Error: "empty link"}
	}

	switch {
	case strings.HasPrefix(link, "ss://"):
		bean, err := parseShadowsocksLink(link)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("shadowsocks", bean)}

	case strings.HasPrefix(link, "vmess://"):
		bean, err := parseVMessLink(link)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("vmess", bean)}

	case strings.HasPrefix(link, "vless://"):
		bean, err := parseTrojanVLESSLink(link, nekokfmt.TrojanVLESSProxyVLESS)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("vless", bean)}

	case strings.HasPrefix(link, "trojan://"):
		bean, err := parseTrojanVLESSLink(link, nekokfmt.TrojanVLESSProxyTrojan)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("trojan", bean)}

	case strings.HasPrefix(link, "hysteria2://"), strings.HasPrefix(link, "hy2://"):
		bean, err := parseQUICLink(link, nekokfmt.QUICProxyHysteria2)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("hysteria2", bean)}

	case strings.HasPrefix(link, "tuic://"):
		bean, err := parseQUICLink(link, nekokfmt.QUICProxyTUIC)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("tuic", bean)}

	case strings.HasPrefix(link, "socks4://"), strings.HasPrefix(link, "socks4a://"),
		strings.HasPrefix(link, "socks5://"), strings.HasPrefix(link, "socks://"):
		bean, err := parseSocksHTTPLink(link, nekokfmt.SocksHttpTypeSocks)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("socks", bean)}

	case strings.HasPrefix(link, "http://"), strings.HasPrefix(link, "https://"):
		bean, err := parseSocksHTTPLink(link, nekokfmt.SocksHttpTypeHTTP)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("http", bean)}

	case strings.HasPrefix(link, "naive+https://"), strings.HasPrefix(link, "naive://"):
		bean, err := parseNaiveLink(link)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("naive", bean)}

	case strings.HasPrefix(link, "anytls://"):
		bean, err := parseAnyTLSLink(link)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("anytls", bean)}

	case strings.HasPrefix(link, "ssh://"):
		bean, err := parseSSHLink(link)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("ssh", bean)}

	case strings.HasPrefix(link, "wireguard://"), strings.HasPrefix(link, "wg://"):
		bean, err := parseWireGuardLink(link)
		if err != nil {
			return ParseResult{Error: err.Error()}
		}
		return ParseResult{Profile: newEntity("wireguard", bean)}
	}

	return ParseResult{Error: "unsupported link scheme: " + link}
}

func newEntity(t string, bean interface{}) *nekokfmt.ProxyEntity {
	beanBytes, _ := json.Marshal(bean)
	return &nekokfmt.ProxyEntity{
		Type: t,
		Id:   -1,
		Bean: beanBytes,
	}
}

// --- helpers ---

func decodeB64IfValid(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	// pad
	if m := len(s) % 4; m != 0 {
		s += strings.Repeat("=", 4-m)
	}
	if b, err := base64.URLEncoding.DecodeString(s); err == nil {
		return string(b)
	}
	if b, err := base64.StdEncoding.DecodeString(s); err == nil {
		return string(b)
	}
	return ""
}

func subBefore(s, sep string) string {
	if i := strings.Index(s, sep); i >= 0 {
		return s[:i]
	}
	return s
}

func subAfter(s, sep string) string {
	if i := strings.Index(s, sep); i >= 0 {
		return s[i+len(sep):]
	}
	return ""
}

func queryValue(q url.Values, key, def string) string {
	v := q.Get(key)
	if v == "" {
		return def
	}
	return v
}

func defaultPort(scheme string) int {
	switch scheme {
	case "http", "vless", "vmess", "trojan", "tuic":
		return 443
	case "https":
		return 443
	default:
		return 1080
	}
}

// parseSocksHTTPLink parses socks/http links.
func parseSocksHTTPLink(link string, defaultType int) (*nekokfmt.SocksHttpBean, error) {
	u, err := url.Parse(link)
	if err != nil || u.Host == "" {
		return nil, fmt.Errorf("invalid url")
	}
	bean := &nekokfmt.SocksHttpBean{
		SocksHttpType: defaultType,
		Stream:        &nekokfmt.V2RayStreamSettings{Network: "tcp"},
	}
	if strings.HasPrefix(link, "socks4") {
		bean.SocksHttpType = nekokfmt.SocksHttpTypeSocks4
	}
	if strings.HasPrefix(link, "http") {
		bean.SocksHttpType = nekokfmt.SocksHttpTypeHTTP
	}
	bean.Name = u.Fragment
	bean.ServerAddress = u.Hostname()
	port, _ := strconv.Atoi(u.Port())
	if port == 0 {
		port = defaultPort("socks")
	}
	bean.ServerPort = port
	bean.Username = u.User.Username()
	bean.Password, _ = u.User.Password()

	// v2rayN fmt: username is base64(user:pass)
	if bean.Password == "" && bean.Username != "" {
		if n := decodeB64IfValid(bean.Username); n != "" {
			bean.Username = subBefore(n, ":")
			bean.Password = subAfter(n, ":")
		}
	}

	q := u.Query()
	bean.Stream.Security = q.Get("security")
	bean.Stream.Sni = q.Get("sni")
	if strings.HasPrefix(link, "https") {
		bean.Stream.Security = "tls"
	}

	if bean.ServerAddress == "" {
		return nil, fmt.Errorf("empty server")
	}
	return bean, nil
}

// parseTrojanVLESSLink parses trojan/vless links.
func parseTrojanVLESSLink(link string, proxyType int) (*nekokfmt.TrojanVLESSBean, error) {
	u, err := url.Parse(link)
	if err != nil || u.Host == "" {
		return nil, fmt.Errorf("invalid url")
	}
	bean := &nekokfmt.TrojanVLESSBean{
		ProxyType: proxyType,
		Stream:    &nekokfmt.V2RayStreamSettings{Network: "tcp"},
	}
	bean.Name = u.Fragment
	bean.ServerAddress = u.Hostname()
	port, _ := strconv.Atoi(u.Port())
	if port == 0 {
		port = 443
	}
	bean.ServerPort = port
	bean.Password = u.User.Username()

	q := u.Query()
	network := queryValue(q, "type", "tcp")
	if network == "h2" {
		network = "http"
	}
	bean.Stream.Network = network

	if proxyType == nekokfmt.TrojanVLESSProxyTrojan {
		sec := queryValue(q, "security", "tls")
		sec = strings.ReplaceAll(sec, "reality", "tls")
		sec = strings.ReplaceAll(sec, "none", "")
		bean.Stream.Security = sec
	} else {
		sec := queryValue(q, "security", "")
		sec = strings.ReplaceAll(sec, "reality", "tls")
		sec = strings.ReplaceAll(sec, "none", "")
		bean.Stream.Security = sec
	}

	sni1 := q.Get("sni")
	sni2 := q.Get("peer")
	if sni1 != "" {
		bean.Stream.Sni = sni1
	}
	if sni2 != "" {
		bean.Stream.Sni = sni2
	}
	bean.Stream.Alpn = q.Get("alpn")
	if q.Get("allowInsecure") != "" {
		bean.Stream.AllowInsecure = true
	}
	bean.Stream.RealityPbk = q.Get("pbk")
	bean.Stream.RealitySid = q.Get("sid")
	bean.Stream.RealitySpx = q.Get("spx")
	bean.Stream.UtlsFingerprint = q.Get("fp")

	// transport
	switch bean.Stream.Network {
	case "ws":
		bean.Stream.Path = q.Get("path")
		bean.Stream.Host = q.Get("host")
	case "http":
		bean.Stream.Path = q.Get("path")
		bean.Stream.Host = strings.ReplaceAll(q.Get("host"), "|", ",")
	case "httpupgrade":
		bean.Stream.Path = q.Get("path")
		bean.Stream.Host = q.Get("host")
	case "grpc":
		bean.Stream.Path = q.Get("serviceName")
	case "tcp":
		if q.Get("headerType") == "http" {
			bean.Stream.HeaderType = "http"
			bean.Stream.Path = q.Get("path")
			bean.Stream.Host = q.Get("host")
		}
	}

	if proxyType == nekokfmt.TrojanVLESSProxyVLESS {
		bean.Flow = q.Get("flow")
	}

	if bean.Password == "" || bean.ServerAddress == "" {
		return nil, fmt.Errorf("missing password or server")
	}
	return bean, nil
}

// parseShadowsocksLink parses ss:// links.
func parseShadowsocksLink(link string) (*nekokfmt.ShadowSocksBean, error) {
	bean := &nekokfmt.ShadowSocksBean{Stream: &nekokfmt.V2RayStreamSettings{Network: "tcp"}}

	if !strings.Contains(subBefore(link, "#"), "@") {
		// v2rayN format: ss://base64(method:password)@host:port#name
		body := subAfter(link, "ss://")
		encoded := subBefore(body, "@")
		rest := subAfter(body, "@")
		if encoded == "" || rest == "" {
			return nil, fmt.Errorf("invalid ss v2rayN format")
		}
		decoded := decodeB64IfValid(encoded)
		if decoded == "" {
			return nil, fmt.Errorf("invalid ss base64")
		}
		bean.Method = subBefore(decoded, ":")
		bean.Password = subAfter(decoded, ":")
		hostPort := subBefore(rest, "#")
		bean.Name = subAfter(rest, "#")
		if h, p, ok := splitHostPort(hostPort); ok {
			bean.ServerAddress = h
			bean.ServerPort = p
		}
	} else {
		// standard / 2022 format
		u, err := url.Parse(link)
		if err != nil || u.Host == "" {
			return nil, fmt.Errorf("invalid ss url")
		}
		bean.Name = u.Fragment
		bean.ServerAddress = u.Hostname()
		port, _ := strconv.Atoi(u.Port())
		bean.ServerPort = port
		if upw, ok := u.User.Password(); ok {
			// 2022 format: username=method, password=password
			bean.Method = u.User.Username()
			bean.Password = upw
		} else {
			// traditional: username=base64(method:password)
			mp := decodeB64IfValid(u.User.Username())
			if mp == "" {
				return nil, fmt.Errorf("invalid ss base64 userinfo")
			}
			bean.Method = subBefore(mp, ":")
			bean.Password = subAfter(mp, ":")
		}
		plugin := u.Query().Get("plugin")
		plugin = strings.ReplaceAll(plugin, "simple-obfs;", "obfs-local;")
		bean.Plugin = plugin
	}

	if bean.ServerAddress == "" || bean.Method == "" || bean.Password == "" {
		return nil, fmt.Errorf("missing ss fields")
	}
	return bean, nil
}

// parseVMessLink parses vmess:// links (v2rayN JSON format + standard format).
func parseVMessLink(link string) (*nekokfmt.VMessBean, error) {
	bean := &nekokfmt.VMessBean{Stream: &nekokfmt.V2RayStreamSettings{Network: "tcp"}}

	body := subAfter(link, "vmess://")
	// v2rayN JSON format
	if decoded := decodeB64IfValid(body); decoded != "" && strings.HasPrefix(strings.TrimSpace(decoded), "{") {
		var obj map[string]interface{}
		if err := json.Unmarshal([]byte(decoded), &obj); err != nil {
			return nil, fmt.Errorf("invalid vmess json: %v", err)
		}
		bean.Uuid = getStr(obj, "id")
		bean.ServerAddress = getStr(obj, "add")
		bean.ServerPort = getInt(obj, "port")
		bean.Name = getStr(obj, "ps")
		bean.Aid = getInt(obj, "aid")
		bean.Stream.Host = getStr(obj, "host")
		bean.Stream.Path = getStr(obj, "path")
		bean.Stream.Sni = getStr(obj, "sni")
		bean.Stream.HeaderType = getStr(obj, "type")
		net := getStr(obj, "net")
		if net == "h2" {
			net = "http"
		}
		if net != "" {
			bean.Stream.Network = net
		}
		scy := getStr(obj, "scy")
		if scy != "" {
			bean.Security = scy
		}
		bean.Stream.Security = getStr(obj, "tls")
		if bean.Security == "" {
			bean.Security = "auto"
		}
		if bean.Uuid == "" || bean.ServerAddress == "" {
			return nil, fmt.Errorf("missing vmess fields")
		}
		return bean, nil
	}

	// standard format
	u, err := url.Parse(link)
	if err != nil || u.Host == "" {
		return nil, fmt.Errorf("invalid vmess url")
	}
	q := u.Query()
	bean.Name = u.Fragment
	bean.ServerAddress = u.Hostname()
	port, _ := strconv.Atoi(u.Port())
	if port == 0 {
		port = 443
	}
	bean.ServerPort = port
	bean.Uuid = u.User.Username()
	bean.Aid = 0
	bean.Security = queryValue(q, "encryption", "auto")

	network := queryValue(q, "type", "tcp")
	if network == "h2" {
		network = "http"
	}
	bean.Stream.Network = network
	sec := queryValue(q, "security", "tls")
	sec = strings.ReplaceAll(sec, "reality", "tls")
	bean.Stream.Security = sec
	sni1 := q.Get("sni")
	sni2 := q.Get("peer")
	if sni1 != "" {
		bean.Stream.Sni = sni1
	}
	if sni2 != "" {
		bean.Stream.Sni = sni2
	}
	if q.Get("allowInsecure") != "" {
		bean.Stream.AllowInsecure = true
	}
	bean.Stream.RealityPbk = q.Get("pbk")
	bean.Stream.RealitySid = q.Get("sid")
	bean.Stream.RealitySpx = q.Get("spx")
	bean.Stream.UtlsFingerprint = q.Get("fp")

	switch bean.Stream.Network {
	case "ws":
		bean.Stream.Path = q.Get("path")
		bean.Stream.Host = q.Get("host")
	case "http":
		bean.Stream.Path = q.Get("path")
		bean.Stream.Host = strings.ReplaceAll(q.Get("host"), "|", ",")
	case "httpupgrade":
		bean.Stream.Path = q.Get("path")
		bean.Stream.Host = q.Get("host")
	case "grpc":
		bean.Stream.Path = q.Get("serviceName")
	case "tcp":
		if q.Get("headerType") == "http" {
			bean.Stream.HeaderType = "http"
			bean.Stream.Path = q.Get("path")
			bean.Stream.Host = q.Get("host")
		}
	}

	if bean.Uuid == "" || bean.ServerAddress == "" {
		return nil, fmt.Errorf("missing vmess fields")
	}
	return bean, nil
}

// parseQUICLink parses hysteria2/hy2/tuic links.
func parseQUICLink(link string, proxyType int) (*nekokfmt.QUICBean, error) {
	u, err := url.Parse(link)
	if err != nil || u.Host == "" {
		return nil, fmt.Errorf("invalid quic url")
	}
	bean := &nekokfmt.QUICBean{ProxyType: proxyType}
	q := u.Query()
	bean.Name = u.Fragment
	bean.ServerAddress = u.Hostname()
	port, _ := strconv.Atoi(u.Port())
	if port == 0 {
		port = 443
	}
	bean.ServerPort = port

	if proxyType == nekokfmt.QUICProxyTUIC {
		bean.Uuid = u.User.Username()
		bean.Password, _ = u.User.Password()
		bean.CongestionControl = q.Get("congestion_control")
		bean.Alpn = q.Get("alpn")
		bean.Sni = q.Get("sni")
		bean.UdpRelayMode = q.Get("udp_relay_mode")
		bean.AllowInsecure = q.Get("allow_insecure") == "1"
		bean.DisableSni = q.Get("disable_sni") == "1"
	} else { // hysteria2
		bean.HopPort = q.Get("mport")
		bean.ObfsPassword = q.Get("obfs-password")
		bean.AllowInsecure = q.Get("insecure") == "1" || q.Get("insecure") == "true"
		if upw, ok := u.User.Password(); ok {
			bean.Password = u.User.Username() + ":" + upw
		} else {
			bean.Password = u.User.Username()
		}
		bean.Sni = q.Get("sni")
	}

	return bean, nil
}

func splitHostPort(s string) (host string, port int, ok bool) {
	s = strings.TrimPrefix(s, "[")
	if i := strings.LastIndex(s, ":"); i >= 0 {
		host = s[:i]
		port, _ = strconv.Atoi(s[i+1:])
		if host != "" && port > 0 {
			// restore bracket for ipv6
			if strings.Contains(s, "]") {
				host = "[" + host
			}
			return host, port, true
		}
	}
	return "", 0, false
}

func getStr(m map[string]interface{}, k string) string {
	if v, ok := m[k]; ok {
		switch t := v.(type) {
		case string:
			return t
		case float64:
			return strconv.Itoa(int(t))
		}
	}
	return ""
}

func getInt(m map[string]interface{}, k string) int {
	if v, ok := m[k]; ok {
		switch t := v.(type) {
		case float64:
			return int(t)
		case string:
			n, _ := strconv.Atoi(t)
			return n
		}
	}
	return 0
}

// --- naive / anytls / ssh / wireguard link parsers ---

// parseNaiveLink parses naive+https://username:password@host:port links.
func parseNaiveLink(link string) (*nekokfmt.NaiveBean, error) {
	// Normalize scheme to https:// for url.Parse
	normalized := strings.Replace(link, "naive+https://", "https://", 1)
	normalized = strings.Replace(normalized, "naive://", "https://", 1)
	u, err := url.Parse(normalized)
	if err != nil || u.Hostname() == "" {
		return nil, fmt.Errorf("invalid naive link")
	}
	port := 443
	if p := u.Port(); p != "" {
		port, _ = strconv.Atoi(p)
	}
	bean := &nekokfmt.NaiveBean{
		Username: u.User.Username(),
		Password: "",
	}
	if pass, ok := u.User.Password(); ok {
		bean.Password = pass
	}
	bean.ServerAddress = u.Hostname()
	bean.ServerPort = port
	if q := u.Query(); q != nil {
		bean.Sni = queryValue(q, "sni", u.Hostname())
		if q.Get("insecure") == "1" || q.Get("allow_insecure") == "1" {
			bean.AllowInsecure = true
		}
		if alpn := q.Get("alpn"); alpn != "" {
			bean.Alpn = alpn
		}
		if q.Get("quic") == "1" {
			bean.QUIC = true
		}
	} else {
		bean.Sni = u.Hostname()
	}
	return bean, nil
}

// parseAnyTLSLink parses anytls://password@host:port links.
func parseAnyTLSLink(link string) (*nekokfmt.AnyTLSBean, error) {
	u, err := url.Parse(link)
	if err != nil || u.Hostname() == "" {
		return nil, fmt.Errorf("invalid anytls link")
	}
	port := 443
	if p := u.Port(); p != "" {
		port, _ = strconv.Atoi(p)
	}
	bean := &nekokfmt.AnyTLSBean{}
	// password is the userinfo (no username)
	if pass, ok := u.User.Password(); ok {
		bean.Password = pass
	} else if u.User.Username() != "" {
		bean.Password = u.User.Username()
	}
	bean.ServerAddress = u.Hostname()
	bean.ServerPort = port
	if q := u.Query(); q != nil {
		bean.Sni = queryValue(q, "sni", u.Hostname())
		if q.Get("insecure") == "1" || q.Get("allow_insecure") == "1" {
			bean.AllowInsecure = true
		}
		if alpn := q.Get("alpn"); alpn != "" {
			bean.Alpn = alpn
		}
		if s := q.Get("min_idle_session"); s != "" {
			bean.MinIdleSession, _ = strconv.Atoi(s)
		}
		if s := q.Get("client_metadata"); s != "" {
			bean.ClientMetadata = s
		}
	} else {
		bean.Sni = u.Hostname()
	}
	return bean, nil
}

// parseSSHLink parses ssh://user[:password]@host:port links.
func parseSSHLink(link string) (*nekokfmt.SSHBean, error) {
	u, err := url.Parse(link)
	if err != nil || u.Hostname() == "" {
		return nil, fmt.Errorf("invalid ssh link")
	}
	port := 22
	if p := u.Port(); p != "" {
		port, _ = strconv.Atoi(p)
	}
	bean := &nekokfmt.SSHBean{
		User: u.User.Username(),
	}
	if pass, ok := u.User.Password(); ok {
		bean.Password = pass
	}
	bean.ServerAddress = u.Hostname()
	bean.ServerPort = port
	if q := u.Query(); q != nil {
		if s := q.Get("private_key"); s != "" {
			bean.PrivateKey = s
		}
		if s := q.Get("host_key_algorithms"); s != "" {
			bean.HostKeyAlgorithms = s
		}
		if s := q.Get("client_version"); s != "" {
			bean.ClientVersion = s
		}
	}
	return bean, nil
}

// parseWireGuardLink parses wireguard://privatekey@host:port?params links.
// The key (private_key) is the userinfo password part.
func parseWireGuardLink(link string) (*nekokfmt.WireGuardBean, error) {
	// Replace wg:// for url.Parse
	normalized := strings.Replace(link, "wg://", "wireguard://", 1)
	u, err := url.Parse(normalized)
	if err != nil || u.Hostname() == "" {
		return nil, fmt.Errorf("invalid wireguard link")
	}
	port := 51820
	if p := u.Port(); p != "" {
		port, _ = strconv.Atoi(p)
	}
	bean := &nekokfmt.WireGuardBean{}
	// Private key can be the password or username part of userinfo
	if pass, ok := u.User.Password(); ok {
		bean.PrivateKey = pass
	} else if u.User.Username() != "" {
		bean.PrivateKey = u.User.Username()
	}
	bean.ServerAddress = u.Hostname()
	bean.ServerPort = port
	bean.PeerAddress = u.Hostname()
	bean.PeerPort = port

	if q := u.Query(); q != nil {
		if s := q.Get("address"); s != "" {
			bean.Address = s
		}
		if s := q.Get("public_key"); s != "" {
			bean.PeerPublicKey = s
		}
		if s := q.Get("pre_shared_key"); s != "" {
			bean.PeerPreSharedKey = s
		}
		if s := q.Get("allowed_ips"); s != "" {
			bean.PeerAllowedIPs = s
		}
		if s := q.Get("mtu"); s != "" {
			bean.MTU, _ = strconv.Atoi(s)
		}
		if s := q.Get("keepalive"); s != "" {
			bean.PeerKeepAlive, _ = strconv.Atoi(s)
		}
		if s := q.Get("reserved"); s != "" {
			bean.PeerReserved = s
		}
	}
	if bean.Address == "" {
		bean.Address = "10.0.0.2/32"
	}
	if bean.PeerAllowedIPs == "" {
		bean.PeerAllowedIPs = "0.0.0.0/0,::/0"
	}
	return bean, nil
}
