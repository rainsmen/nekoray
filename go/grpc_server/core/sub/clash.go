package sub

import (
	"fmt"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
	nekokfmt "grpc_server/core/fmt"
)

// parseClash parses a Clash YAML subscription.
//
// Mirrors RawUpdater::updateClash in C++ sub/GroupUpdater.cpp.
func parseClash(content string) []ParseResult {
	var doc struct {
		Proxies []map[string]interface{} `yaml:"proxies"`
	}
	if err := yaml.Unmarshal([]byte(content), &doc); err != nil {
		return []ParseResult{{Error: "invalid clash yaml: " + err.Error()}}
	}

	var results []ParseResult
	for _, proxy := range doc.Proxies {
		r := parseClashProxy(proxy)
		results = append(results, r)
	}
	return results
}

func parseClashProxy(proxy map[string]interface{}) ParseResult {
	typeStr := lower(nodeStr(proxy["type"]))
	origType := typeStr

	if typeStr == "ss" || typeStr == "ssr" {
		typeStr = "shadowsocks"
	}
	if typeStr == "socks5" {
		typeStr = "socks"
	}

	name := nodeStr(proxy["name"])
	server := nodeStr(proxy["server"])
	port := nodeInt(proxy["port"])

	switch origType {
	case "ss", "ssr":
		bean := &nekokfmt.ShadowSocksBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			Method:   strings.ReplaceAll(nodeStr(proxy["cipher"]), "dummy", "none"),
			Password: nodeStr(proxy["password"]),
			Stream:   &nekokfmt.V2RayStreamSettings{Network: "tcp"},
		}
		// plugin
		if plugin := proxy["plugin"]; plugin != nil {
			pluginOpts := proxy["plugin-opts"]
			bean.Plugin = clashSSPlugin(nodeStr(plugin), pluginOpts)
		}
		// udp-over-tcp
		if nodeBool(proxy["udp-over-tcp"]) {
			v := nodeInt(proxy["udp-over-tcp-version"])
			if v == 0 {
				v = 2
			}
			bean.Uot = v
		}
		// smux
		if smux, ok := proxy["smux"].(map[string]interface{}); ok && nodeBool(smux["enabled"]) {
			bean.Stream.MultiplexStatus = 1
		}
		return ParseResult{Profile: newEntity("shadowsocks", bean)}

	case "socks", "http":
		bean := &nekokfmt.SocksHttpBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			Username: nodeStr(proxy["username"]),
			Password: nodeStr(proxy["password"]),
			Stream:   &nekokfmt.V2RayStreamSettings{Network: "tcp"},
		}
		if origType == "http" {
			bean.SocksHttpType = nekokfmt.SocksHttpTypeHTTP
		}
		if nodeBool(proxy["tls"]) {
			bean.Stream.Security = "tls"
		}
		if nodeBool(proxy["skip-cert-verify"]) {
			bean.Stream.AllowInsecure = true
		}
		bean.Stream.Sni = firstOrSecond(nodeStr(proxy["sni"]), nodeStr(proxy["servername"]))
		return ParseResult{Profile: newEntity(origType, bean)}

	case "trojan", "vless":
		bean := &nekokfmt.TrojanVLESSBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			Stream: &nekokfmt.V2RayStreamSettings{
				Network:  firstOrSecond(nodeStr(proxy["network"]), "tcp"),
				Security: "tls",
			},
		}
		if origType == "vless" {
			bean.ProxyType = nekokfmt.TrojanVLESSProxyVLESS
			bean.Flow = nodeStr(proxy["flow"])
			bean.Password = nodeStr(proxy["uuid"])
			if nodeBool(proxy["packet-addr"]) {
				bean.Stream.PacketEncoding = "packetaddr"
			} else {
				bean.Stream.PacketEncoding = "xudp"
			}
		} else {
			bean.ProxyType = nekokfmt.TrojanVLESSProxyTrojan
			bean.Password = nodeStr(proxy["password"])
		}
		if strings.HasPrefix(bean.Stream.Network, "h2") {
			bean.Stream.Network = "http"
		}
		bean.Stream.Sni = firstOrSecond(nodeStr(proxy["sni"]), nodeStr(proxy["servername"]))
		bean.Stream.Alpn = joinStrList(proxy["alpn"], ",")
		bean.Stream.AllowInsecure = nodeBool(proxy["skip-cert-verify"])
		bean.Stream.UtlsFingerprint = nodeStr(proxy["client-fingerprint"])

		// smux
		if smux, ok := proxy["smux"].(map[string]interface{}); ok && nodeBool(smux["enabled"]) {
			bean.Stream.MultiplexStatus = 1
		}

		// ws-opts
		if ws := nodeChild(proxy, "ws-opts", "ws-opt"); ws != nil {
			bean.Stream.Host = wsHeaderHost(ws)
			bean.Stream.Path = nodeStr(ws["path"])
			bean.Stream.WsEarlyDataLen = nodeInt(ws["max-early-data"])
			bean.Stream.WsEarlyDataName = nodeStr(ws["early-data-header-name"])
		}
		// grpc-opts
		if grpc := nodeChild(proxy, "grpc-opts", "grpc-opt"); grpc != nil {
			bean.Stream.Path = nodeStr(grpc["grpc-service-name"])
		}
		// reality-opts
		if reality := nodeChild(proxy, "reality-opts"); reality != nil {
			bean.Stream.RealityPbk = nodeStr(reality["public-key"])
			bean.Stream.RealitySid = nodeStr(reality["short-id"])
		}
		return ParseResult{Profile: newEntity(origType, bean)}

	case "vmess":
		bean := &nekokfmt.VMessBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			Uuid:     nodeStr(proxy["uuid"]),
			Aid:      nodeInt(proxy["alterId"]),
			Security: firstOrSecond(nodeStr(proxy["cipher"]), "auto"),
			Stream: &nekokfmt.V2RayStreamSettings{
				Network: strings.ReplaceAll(firstOrSecond(nodeStr(proxy["network"]), "tcp"), "h2", "http"),
			},
		}
		bean.Stream.Sni = firstOrSecond(nodeStr(proxy["sni"]), nodeStr(proxy["servername"]))
		bean.Stream.Alpn = joinStrList(proxy["alpn"], ",")
		if nodeBool(proxy["tls"]) {
			bean.Stream.Security = "tls"
		}
		if nodeBool(proxy["skip-cert-verify"]) {
			bean.Stream.AllowInsecure = true
		}
		bean.Stream.UtlsFingerprint = nodeStr(proxy["client-fingerprint"])
		if nodeBool(proxy["xudp"]) {
			bean.Stream.PacketEncoding = "xudp"
		}
		if nodeBool(proxy["packet-addr"]) {
			bean.Stream.PacketEncoding = "packetaddr"
		}
		if smux, ok := proxy["smux"].(map[string]interface{}); ok && nodeBool(smux["enabled"]) {
			bean.Stream.MultiplexStatus = 1
		}
		if ws := nodeChild(proxy, "ws-opts", "ws-opt"); ws != nil {
			bean.Stream.Host = wsHeaderHost(ws)
			bean.Stream.Path = nodeStr(ws["path"])
			bean.Stream.WsEarlyDataLen = nodeInt(ws["max-early-data"])
			bean.Stream.WsEarlyDataName = nodeStr(ws["early-data-header-name"])
		}
		if grpc := nodeChild(proxy, "grpc-opts", "grpc-opt"); grpc != nil {
			bean.Stream.Path = nodeStr(grpc["grpc-service-name"])
		}
		if h2 := nodeChild(proxy, "h2-opts", "h2-opt"); h2 != nil {
			bean.Stream.Host = firstListStr(h2["host"])
			bean.Stream.Path = nodeStr(h2["path"])
		}
		if hp := nodeChild(proxy, "http-opts", "http-opt"); hp != nil {
			bean.Stream.Network = "tcp"
			bean.Stream.HeaderType = "http"
			bean.Stream.Host = firstListStr(hp["headers"])
			bean.Stream.Path = firstListStr(hp["path"])
		}
		return ParseResult{Profile: newEntity("vmess", bean)}

	case "hysteria2":
		bean := &nekokfmt.QUICBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			ProxyType:     nekokfmt.QUICProxyHysteria2,
			HopPort:       nodeStr(proxy["ports"]),
			AllowInsecure: nodeBool(proxy["skip-cert-verify"]),
			CaText:        nodeStr(proxy["ca-str"]),
			Sni:           nodeStr(proxy["sni"]),
			ObfsPassword:  nodeStr(proxy["obfs-password"]),
			Password:      nodeStr(proxy["password"]),
			UploadMbps:    firstInt(nodeStr(proxy["up"])),
			DownloadMbps:  firstInt(nodeStr(proxy["down"])),
		}
		return ParseResult{Profile: newEntity("hysteria2", bean)}

	case "tuic":
		bean := &nekokfmt.QUICBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			ProxyType:         nekokfmt.QUICProxyTUIC,
			Uuid:              nodeStr(proxy["uuid"]),
			Password:          nodeStr(proxy["password"]),
			UdpRelayMode:      firstOrSecond(nodeStr(proxy["udp-relay-mode"]), "native"),
			CongestionControl: firstOrSecond(nodeStr(proxy["congestion-controller"]), "bbr"),
			DisableSni:        nodeBool(proxy["disable-sni"]),
			ZeroRttHandshake:  nodeBool(proxy["reduce-rtt"]),
			AllowInsecure:     nodeBool(proxy["skip-cert-verify"]),
			Alpn:              joinStrList(proxy["alpn"], ","),
			CaText:            nodeStr(proxy["ca-str"]),
			Sni:               nodeStr(proxy["sni"]),
		}
		if nodeBool(proxy["udp-over-stream"]) {
			bean.Uos = true
		}
		if ip := nodeStr(proxy["ip"]); ip != "" {
			if bean.Sni == "" {
				bean.Sni = bean.ServerAddress
			}
			bean.ServerAddress = ip
		}
		return ParseResult{Profile: newEntity("tuic", bean)}

	case "naive":
		bean := &nekokfmt.NaiveBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			Username:      nodeStr(proxy["username"]),
			Password:      nodeStr(proxy["password"]),
			Sni:           nodeStr(proxy["sni"]),
			AllowInsecure: nodeBool(proxy["skip-cert-verify"]),
		}
		return ParseResult{Profile: newEntity("naive", bean)}

	case "anytls":
		bean := &nekokfmt.AnyTLSBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			Password:      nodeStr(proxy["password"]),
			Sni:           nodeStr(proxy["sni"]),
			AllowInsecure: nodeBool(proxy["skip-cert-verify"]),
		}
		if v := proxy["min-idle-session"]; v != nil {
			bean.MinIdleSession = nodeInt(v)
		}
		if s := nodeStr(proxy["client-metadata"]); s != "" {
			bean.ClientMetadata = s
		}
		return ParseResult{Profile: newEntity("anytls", bean)}

	case "ssh":
		bean := &nekokfmt.SSHBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			User:     nodeStr(proxy["username"]),
			Password: nodeStr(proxy["password"]),
		}
		if s := nodeStr(proxy["client-version"]); s != "" {
			bean.ClientVersion = s
		}
		return ParseResult{Profile: newEntity("ssh", bean)}

	case "wireguard":
		bean := &nekokfmt.WireGuardBean{
			AbstractBean: nekokfmt.AbstractBean{
				Name:          name,
				ServerAddress: server,
				ServerPort:    port,
			},
			PrivateKey: nodeStr(proxy["private-key"]),
			MTU:        nodeInt(proxy["mtu"]),
		}
		if s := joinStrList(proxy["address"], ","); s != "" {
			bean.Address = s
		}
		// peers (clash typically has a single peer section)
		if peers, ok := proxy["peers"].([]interface{}); ok && len(peers) > 0 {
			if peer, ok := peers[0].(map[string]interface{}); ok {
				bean.PeerPublicKey = nodeStr(peer["public-key"])
				bean.PeerPreSharedKey = nodeStr(peer["pre-shared-key"])
				bean.PeerAllowedIPs = joinStrList(peer["allowed-ips"], ",")
				bean.PeerKeepAlive = nodeInt(peer["persistent-keepalive"])
			}
		} else {
			// Some clash configs use flat keys
			bean.PeerPublicKey = nodeStr(proxy["public-key"])
			bean.PeerPreSharedKey = nodeStr(proxy["pre-shared-key"])
			bean.PeerAllowedIPs = joinStrList(proxy["allowed-ips"], ",")
			bean.PeerKeepAlive = nodeInt(proxy["persistent-keepalive"])
		}
		if bean.Address == "" {
			bean.Address = "10.0.0.2/32"
		}
		if bean.PeerAllowedIPs == "" {
			bean.PeerAllowedIPs = "0.0.0.0/0,::/0"
		}
		return ParseResult{Profile: newEntity("wireguard", bean)}
	}

	return ParseResult{Error: fmt.Sprintf("unsupported clash proxy type: %s", origType)}
}

// clashSSPlugin builds the ss plugin string from clash plugin + plugin-opts.
func clashSSPlugin(plugin string, opts interface{}) string {
	if opts == nil {
		return plugin
	}
	m, ok := opts.(map[string]interface{})
	if !ok {
		return plugin
	}
	var parts []string
	switch plugin {
	case "obfs":
		parts = append(parts, "obfs-local")
		parts = append(parts, "obfs="+nodeStr(m["mode"]))
		parts = append(parts, "obfs-host="+nodeStr(m["host"]))
	case "v2ray-plugin":
		parts = append(parts, "v2ray-plugin")
		mode := nodeStr(m["mode"])
		if mode != "" && mode != "websocket" {
			parts = append(parts, "mode="+mode)
		}
		if nodeBool(m["tls"]) {
			parts = append(parts, "tls")
		}
		host := nodeStr(m["host"])
		if host != "" {
			parts = append(parts, "host="+host)
		}
		path := nodeStr(m["path"])
		if path != "" {
			parts = append(parts, "path="+path)
		}
	default:
		return plugin
	}
	return strings.Join(parts, ";")
}

// --- yaml helpers ---

func nodeStr(v interface{}) string {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return t
	case int:
		return strconv.Itoa(t)
	case uint64:
		return strconv.FormatUint(t, 10)
	case int64:
		return strconv.FormatInt(t, 10)
	case float64:
		return strconv.Itoa(int(t))
	case bool:
		if t {
			return "true"
		}
		return "false"
	}
	return fmt.Sprintf("%v", v)
}

func nodeInt(v interface{}) int {
	if v == nil {
		return 0
	}
	switch t := v.(type) {
	case int:
		return t
	case int64:
		return int(t)
	case float64:
		return int(t)
	case string:
		n, _ := strconv.Atoi(t)
		return n
	}
	return 0
}

func nodeBool(v interface{}) bool {
	if v == nil {
		return false
	}
	switch t := v.(type) {
	case bool:
		return t
	case string:
		return t == "1" || t == "true"
	case int:
		return t != 0
	case float64:
		return t != 0
	}
	return false
}

func lower(s string) string { return strings.ToLower(s) }

func firstOrSecond(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

func joinStrList(v interface{}, sep string) string {
	switch t := v.(type) {
	case []interface{}:
		var parts []string
		for _, item := range t {
			parts = append(parts, nodeStr(item))
		}
		return strings.Join(parts, sep)
	case string:
		return t
	}
	return ""
}

func firstListStr(v interface{}) string {
	switch t := v.(type) {
	case []interface{}:
		if len(t) > 0 {
			return nodeStr(t[0])
		}
	case map[string]interface{}:
		for _, val := range t {
			switch arr := val.(type) {
			case []interface{}:
				if len(arr) > 0 {
					return nodeStr(arr[0])
				}
			default:
				return nodeStr(val)
			}
		}
	}
	return ""
}

func nodeChild(m map[string]interface{}, keys ...string) map[string]interface{} {
	for _, k := range keys {
		if v, ok := m[k]; ok {
			if mm, ok := v.(map[string]interface{}); ok {
				return mm
			}
		}
	}
	return nil
}

func wsHeaderHost(ws map[string]interface{}) string {
	headers := ws["headers"]
	if headers == nil {
		return ""
	}
	if m, ok := headers.(map[string]interface{}); ok {
		for k, v := range m {
			if strings.ToLower(k) == "host" {
				return nodeStr(v)
			}
		}
	}
	return ""
}

func firstInt(s string) int {
	parts := strings.Fields(s)
	if len(parts) > 0 {
		n, _ := strconv.Atoi(parts[0])
		return n
	}
	return 0
}
