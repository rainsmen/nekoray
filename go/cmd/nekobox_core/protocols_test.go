package main

import (
	"encoding/json"
	"strings"
	"testing"

	"grpc_server/core/config"
	nekokfmt "grpc_server/core/fmt"
)

func TestAllProtocolsCreateInstance(t *testing.T) {
	// Standard routing configuration with DoH DNS (the exact trigger of the previous DNS transport registry bug)
	routing := &nekokfmt.Routing{
		DefOutbound:       "proxy",
		RemoteDNS:         "https://dns.google/dns-query",
		RemoteDNSStrategy: "ipv4_only",
		DirectDNS:         "https://223.5.5.5/dns-query",
		DirectDNSStrategy: "ipv4_only",
		DNSRouting:        true,
		DomainStrategy:    "ipv4_only",
		SniffingMode:      nekokfmt.SniffingModeForRouting,
	}

	ds := &nekokfmt.DataStore{
		InboundAddress:       "127.0.0.1",
		InboundSocksPort:     0, // test mode
		LogLevel:             "info",
		CoreBoxUnderlyingDNS: "local",
	}

	tests := []struct {
		name string
		ent  *nekokfmt.ProxyEntity
	}{
		{
			name: "NaiveProxy",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.NaiveBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "dmit.zhilutianshi.com",
						ServerPort:    4431,
						Name:          "dmit-naive",
					},
					Username:      "rainman",
					Password:      "rainman2009",
					Sni:           "dmit.zhilutianshi.com",
					AllowInsecure: false,
				})
				return &nekokfmt.ProxyEntity{Type: "naive", Id: 1, Bean: b}
			}(),
		},
		{
			name: "Shadowsocks",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.ShadowSocksBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    8388,
					},
					Method:   "aes-256-gcm",
					Password: "secretpassword",
				})
				return &nekokfmt.ProxyEntity{Type: "shadowsocks", Id: 2, Bean: b}
			}(),
		},
		{
			name: "VMess",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.VMessBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    443,
					},
					Uuid:     "b831381d-6324-4d53-ad4f-8cda48b30811",
					Aid:      0,
					Security: "auto",
					Stream: &nekokfmt.V2RayStreamSettings{
						Network:  "ws",
						Path:     "/ws",
						Security: "tls",
						Sni:      "vmess.example.com",
					},
				})
				return &nekokfmt.ProxyEntity{Type: "vmess", Id: 3, Bean: b}
			}(),
		},
		{
			name: "VLESS_Reality",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.TrojanVLESSBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    443,
					},
					ProxyType: nekokfmt.TrojanVLESSProxyVLESS,
					Password:  "b831381d-6324-4d53-ad4f-8cda48b30811",
					Flow:      "xtls-rprx-vision",
					Stream: &nekokfmt.V2RayStreamSettings{
						Network:    "tcp",
						Security:   "tls",
						Sni:        "yahoo.com",
						RealityPbk: "cGFzc3dvcmQxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ",
						RealitySid: "6ba85179",
					},
				})
				return &nekokfmt.ProxyEntity{Type: "vless", Id: 4, Bean: b}
			}(),
		},
		{
			name: "Trojan",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.TrojanVLESSBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    443,
					},
					ProxyType: nekokfmt.TrojanVLESSProxyTrojan,
					Password:  "trojanpassword",
					Stream: &nekokfmt.V2RayStreamSettings{
						Network:  "tcp",
						Security: "tls",
						Sni:      "trojan.example.com",
					},
				})
				return &nekokfmt.ProxyEntity{Type: "trojan", Id: 5, Bean: b}
			}(),
		},
		{
			name: "Hysteria2",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.QUICBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    443,
					},
					ProxyType:    nekokfmt.QUICProxyHysteria2,
					Password:     "hysteria2password",
					UploadMbps:   100,
					DownloadMbps: 500,
					Sni:          "hy2.example.com",
				})
				return &nekokfmt.ProxyEntity{Type: "hysteria2", Id: 6, Bean: b}
			}(),
		},
		{
			name: "TUIC",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.QUICBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    443,
					},
					ProxyType:         nekokfmt.QUICProxyTUIC,
					Uuid:              "b831381d-6324-4d53-ad4f-8cda48b30811",
					Password:          "tuicpassword",
					CongestionControl: "bbr",
					UdpRelayMode:      "native",
					Sni:               "tuic.example.com",
				})
				return &nekokfmt.ProxyEntity{Type: "tuic", Id: 7, Bean: b}
			}(),
		},
		{
			name: "AnyTLS",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.AnyTLSBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    443,
					},
					Password: "anytlspassword",
					Sni:      "anytls.example.com",
				})
				return &nekokfmt.ProxyEntity{Type: "anytls", Id: 8, Bean: b}
			}(),
		},
		{
			name: "SSH",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.SSHBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    22,
					},
					User:     "root",
					Password: "sshpassword",
				})
				return &nekokfmt.ProxyEntity{Type: "ssh", Id: 9, Bean: b}
			}(),
		},
		{
			name: "WireGuard",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.WireGuardBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    51820,
					},
					PrivateKey:    "cGFzc3dvcmQxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ=",
					PeerPublicKey: "cGFzc3dvcmQxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ=",
					Address:       "10.0.0.2/32",
				})
				return &nekokfmt.ProxyEntity{Type: "wireguard", Id: 10, Bean: b}
			}(),
		},
		{
			name: "SOCKS5",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.SocksHttpBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    1080,
					},
					SocksHttpType: nekokfmt.SocksHttpTypeSocks,
				})
				return &nekokfmt.ProxyEntity{Type: "socks", Id: 11, Bean: b}
			}(),
		},
		{
			name: "HTTP",
			ent: func() *nekokfmt.ProxyEntity {
				b, _ := json.Marshal(&nekokfmt.SocksHttpBean{
					AbstractBean: nekokfmt.AbstractBean{
						ServerAddress: "1.2.3.4",
						ServerPort:    8080,
					},
					SocksHttpType: nekokfmt.SocksHttpTypeHTTP,
				})
				return &nekokfmt.ProxyEntity{Type: "http", Id: 12, Bean: b}
			}(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := config.BuildConfig(tt.ent, nil, routing, ds, true, false)
			if res.Error != "" {
				t.Fatalf("BuildConfig failed: %v", res.Error)
			}
			configBytes, err := json.Marshal(res.CoreConfig)
			if err != nil {
				t.Fatalf("json.Marshal failed: %v", err)
			}

			// Verify createInstance succeeds without any "missing registry" or schema error
			inst, cancel, _, err := createInstance(configBytes)
			if err != nil {
				errMsg := err.Error()
				// If running in untagged test environment (e.g. without -tags with_quic/with_wireguard/with_naive_outbound),
				// sing-box stub appropriately reports missing build tag.
				if strings.Contains(errMsg, "not included in this build") || strings.Contains(errMsg, "library not found") {
					t.Logf("Protocol %s build driver stub active: %v", tt.name, err)
					return
				}
				t.Fatalf("createInstance failed for protocol %s: %v\nConfig:\n%s", tt.name, err, string(configBytes))
			}
			defer cancel()
			defer inst.Close()
		})
	}
}
