package config

import (
	"encoding/json"
	"strings"

	nekokfmt "grpc_server/core/fmt"
)

// BuildStreamSettingsSingBox mirrors V2rayStreamSettings::BuildStreamSettingsSingBox.
//
// It writes the transport + tls objects into the outbound map.
func BuildStreamSettingsSingBox(stream *nekokfmt.V2RayStreamSettings, outbound map[string]interface{}) {
	if stream == nil {
		return
	}

	// transport
	if stream.Network != "tcp" {
		transport := map[string]interface{}{"type": stream.Network}
		switch stream.Network {
		case "ws":
			if stream.Host != "" {
				transport["headers"] = map[string]interface{}{"Host": stream.Host}
			}
			pathWithoutEd := subStrBefore(stream.Path, "?ed=")
			if pathWithoutEd != "" {
				transport["path"] = pathWithoutEd
			}
			if pathWithoutEd != stream.Path {
				edStr := subStrAfter(stream.Path, "?ed=")
				if ed := parseInt(edStr); ed > 0 {
					transport["max_early_data"] = ed
					transport["early_data_header_name"] = "Sec-WebSocket-Protocol"
				}
			}
			if stream.WsEarlyDataLen > 0 {
				transport["max_early_data"] = stream.WsEarlyDataLen
				transport["early_data_header_name"] = stream.WsEarlyDataName
			}
		case "http":
			if stream.Path != "" {
				transport["path"] = stream.Path
			}
			if stream.Host != "" {
				transport["host"] = strings.Split(stream.Host, ",")
			}
		case "grpc":
			if stream.Path != "" {
				transport["service_name"] = stream.Path
			}
		case "httpupgrade":
			if stream.Path != "" {
				transport["path"] = stream.Path
			}
			if stream.Host != "" {
				transport["host"] = stream.Host
			}
		}
		outbound["transport"] = transport
	} else if stream.HeaderType == "http" {
		outbound["transport"] = map[string]interface{}{
			"type":   "http",
			"method": "GET",
			"path":   stream.Path,
			"headers": map[string]interface{}{
				"Host": strings.Split(stream.Host, ","),
			},
		}
	}

	// tls
	if stream.Security == "tls" {
		tls := map[string]interface{}{"enabled": true}
		if stream.AllowInsecure {
			tls["insecure"] = true
		}
		if strings.TrimSpace(stream.Sni) != "" {
			tls["server_name"] = stream.Sni
		}
		if strings.TrimSpace(stream.Certificate) != "" {
			tls["certificate"] = strings.TrimSpace(stream.Certificate)
		}
		if strings.TrimSpace(stream.Alpn) != "" {
			tls["alpn"] = strings.Split(stream.Alpn, ",")
		}
		fp := stream.UtlsFingerprint
		if strings.TrimSpace(stream.RealityPbk) != "" {
			sid := stream.RealitySid
			if idx := strings.Index(sid, ","); idx >= 0 {
				sid = sid[:idx]
			}
			tls["reality"] = map[string]interface{}{
				"enabled":   true,
				"public_key": stream.RealityPbk,
				"short_id":   sid,
			}
			if fp == "" {
				fp = "random"
			}
		}
		if fp != "" {
			tls["utls"] = map[string]interface{}{
				"enabled":     true,
				"fingerprint": fp,
			}
		}
		outbound["tls"] = tls
	}

	// packet encoding for vmess/vless
	if outbound["type"] == "vmess" || outbound["type"] == "vless" {
		outbound["packet_encoding"] = stream.PacketEncoding
	}
}

// BuildOutboundSingBox builds a sing-box outbound object for the given bean.
// Mirrors the BuildCoreObjSingBox methods in Bean2CoreObj_box.cpp.
func BuildOutboundSingBox(bean interface{}) (map[string]interface{}, error) {
	switch b := bean.(type) {
	case *nekokfmt.SocksHttpBean:
		return buildSocksHttp(b), nil
	case *nekokfmt.ShadowSocksBean:
		return buildShadowsocks(b), nil
	case *nekokfmt.VMessBean:
		return buildVMess(b), nil
	case *nekokfmt.TrojanVLESSBean:
		return buildTrojanVLESS(b), nil
	case *nekokfmt.QUICBean:
		return buildQUIC(b), nil
	case *nekokfmt.CustomBean:
		if b.Core == "internal" {
			var raw map[string]interface{}
			if err := json.Unmarshal([]byte(b.ConfigSimple), &raw); err != nil {
				return nil, err
			}
			return raw, nil
		}
		return nil, errUnsupportedOutbound
	default:
		return nil, errUnsupportedOutbound
	}
}

var errUnsupportedOutbound = simpleErr2("unsupported outbound")

type simpleErr2 string

func (e simpleErr2) Error() string { return string(e) }

func buildSocksHttp(b *nekokfmt.SocksHttpBean) map[string]interface{} {
	outbound := map[string]interface{}{
		"server":      b.ServerAddress,
		"server_port": b.ServerPort,
	}
	if b.SocksHttpType == nekokfmt.SocksHttpTypeHTTP {
		outbound["type"] = "http"
	} else {
		outbound["type"] = "socks"
		if b.SocksHttpType == nekokfmt.SocksHttpTypeSocks4 {
			outbound["version"] = "4"
		}
	}
	if b.Username != "" && b.Password != "" {
		outbound["username"] = b.Username
		outbound["password"] = b.Password
	}
	BuildStreamSettingsSingBox(b.Stream, outbound)
	return outbound
}

func buildShadowsocks(b *nekokfmt.ShadowSocksBean) map[string]interface{} {
	outbound := map[string]interface{}{
		"type":        "shadowsocks",
		"server":      b.ServerAddress,
		"server_port": b.ServerPort,
		"method":      b.Method,
		"password":    b.Password,
	}
	if b.Uot != 0 {
		outbound["udp_over_tcp"] = map[string]interface{}{
			"enabled": true,
			"version": b.Uot,
		}
	} else {
		outbound["udp_over_tcp"] = false
	}
	if strings.TrimSpace(b.Plugin) != "" {
		outbound["plugin"] = subStrBefore(b.Plugin, ";")
		outbound["plugin_opts"] = subStrAfter(b.Plugin, ";")
	}
	BuildStreamSettingsSingBox(b.Stream, outbound)
	return outbound
}

func buildVMess(b *nekokfmt.VMessBean) map[string]interface{} {
	outbound := map[string]interface{}{
		"type":        "vmess",
		"server":      b.ServerAddress,
		"server_port": b.ServerPort,
		"uuid":        strings.TrimSpace(b.Uuid),
		"alter_id":    b.Aid,
		"security":    b.Security,
	}
	BuildStreamSettingsSingBox(b.Stream, outbound)
	return outbound
}

func buildTrojanVLESS(b *nekokfmt.TrojanVLESSBean) map[string]interface{} {
	outbound := map[string]interface{}{
		"server":      b.ServerAddress,
		"server_port": b.ServerPort,
	}
	if b.ProxyType == nekokfmt.TrojanVLESSProxyVLESS {
		outbound["type"] = "vless"
		flow := b.Flow
		if strings.HasSuffix(flow, "-udp443") {
			flow = strings.TrimSuffix(flow, "-udp443")
		} else if flow == "none" {
			flow = ""
		}
		outbound["uuid"] = strings.TrimSpace(b.Password)
		outbound["flow"] = flow
	} else {
		outbound["type"] = "trojan"
		outbound["password"] = b.Password
	}
	BuildStreamSettingsSingBox(b.Stream, outbound)
	return outbound
}

func buildQUIC(b *nekokfmt.QUICBean) map[string]interface{} {
	coreTls := map[string]interface{}{
		"enabled":     true,
		"disable_sni": b.DisableSni,
		"insecure":    b.AllowInsecure,
		"certificate": strings.TrimSpace(b.CaText),
		"server_name": b.Sni,
	}
	if strings.TrimSpace(b.Alpn) != "" {
		coreTls["alpn"] = strings.Split(b.Alpn, ",")
	}
	if b.ProxyType == nekokfmt.QUICProxyHysteria2 {
		coreTls["alpn"] = "h3"
	}

	outbound := map[string]interface{}{
		"server":      b.ServerAddress,
		"server_port": b.ServerPort,
		"tls":         coreTls,
	}

	if b.ProxyType == nekokfmt.QUICProxyHysteria2 {
		outbound["type"] = "hysteria2"
		outbound["password"] = b.Password
		outbound["up_mbps"] = b.UploadMbps
		outbound["down_mbps"] = b.DownloadMbps
		if strings.TrimSpace(b.HopPort) != "" {
			outbound["hop_ports"] = b.HopPort
			outbound["hop_interval"] = b.HopInterval
		}
		if b.ObfsPassword != "" {
			outbound["obfs"] = map[string]interface{}{
				"type":     "salamander",
				"password": b.ObfsPassword,
			}
		}
	} else if b.ProxyType == nekokfmt.QUICProxyTUIC {
		outbound["type"] = "tuic"
		outbound["uuid"] = b.Uuid
		outbound["password"] = b.Password
		outbound["congestion_control"] = b.CongestionControl
		if b.Uos {
			outbound["udp_over_stream"] = true
		} else {
			outbound["udp_relay_mode"] = b.UdpRelayMode
		}
		outbound["zero_rtt_handshake"] = b.ZeroRttHandshake
		if strings.TrimSpace(b.Heartbeat) != "" {
			outbound["heartbeat"] = b.Heartbeat
		}
	}

	return outbound
}

// --- small string helpers (mirror C++ SubStrBefore/SubStrAfter) ---

func subStrBefore(s, sep string) string {
	if idx := strings.Index(s, sep); idx >= 0 {
		return s[:idx]
	}
	return s
}

func subStrAfter(s, sep string) string {
	if idx := strings.Index(s, sep); idx >= 0 {
		return s[idx+len(sep):]
	}
	return ""
}

func parseInt(s string) int {
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			break
		}
		n = n*10 + int(c-'0')
	}
	return n
}
