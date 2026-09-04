package config

import (
	"encoding/json"
	"strings"
	"testing"

	nekokfmt "grpc_server/core/fmt"
)

// TestBuildVMessConfig verifies that a basic VMess profile produces a valid
// sing-box config with the expected outbound type.
func TestBuildVMessConfig(t *testing.T) {
	stream := &nekokfmt.V2RayStreamSettings{Network: "tcp"}
	bean := &nekokfmt.VMessBean{
		AbstractBean: nekokfmt.AbstractBean{
			Version:       0,
			ServerAddress: "1.2.3.4",
			ServerPort:    443,
		},
		Uuid:     "test-uuid-1234",
		Aid:      0,
		Security: "auto",
		Stream:   stream,
	}
	beanBytes, _ := json.Marshal(bean)

	ent := &nekokfmt.ProxyEntity{
		Type: "vmess",
		Id:   1,
		Gid:  1,
		Bean: beanBytes,
	}
	routing := &nekokfmt.Routing{
		DefOutbound:  "proxy",
		SniffingMode: nekokfmt.SniffingModeForRouting,
	}
	ds := &nekokfmt.DataStore{
		InboundAddress:       "127.0.0.1",
		InboundSocksPort:     2080,
		LogLevel:             "info",
		MuxConcurrency:       0,
		CoreBoxClashAPI:      0,
		CoreBoxUnderlyingDNS: "local",
	}

	result := BuildConfig(ent, nil, routing, ds, false, false)
	if result.Error != "" {
		t.Fatalf("BuildConfig error: %s", result.Error)
	}

	configBytes, err := json.Marshal(result.CoreConfig)
	if err != nil {
		t.Fatalf("marshal config: %v", err)
	}
	configStr := string(configBytes)

	// verify outbound type
	if !strings.Contains(configStr, `"type":"vmess"`) {
		t.Errorf("config missing vmess outbound: %s", configStr)
	}
	// verify server
	if !strings.Contains(configStr, `"server":"1.2.3.4"`) {
		t.Errorf("config missing server address: %s", configStr)
	}
	// verify inbound mixed-in
	if !strings.Contains(configStr, `"type":"mixed"`) {
		t.Errorf("config missing mixed inbound: %s", configStr)
	}
	// verify direct/bypass/block outbounds
	if !strings.Contains(configStr, `"tag":"direct"`) {
		t.Errorf("config missing direct outbound")
	}
	// verify dns section
	if !strings.Contains(configStr, `"dns":`) {
		t.Errorf("config missing dns section")
	}
	// verify route section
	if !strings.Contains(configStr, `"route":`) {
		t.Errorf("config missing route section")
	}

	t.Logf("generated config:\n%s", prettyJSON(t, result.CoreConfig))
}

// TestBuildShadowsocksConfig verifies a Shadowsocks profile.
func TestBuildShadowsocksConfig(t *testing.T) {
	bean := &nekokfmt.ShadowSocksBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "5.6.7.8",
			ServerPort:    8388,
		},
		Method:   "aes-256-gcm",
		Password: "secret",
	}
	beanBytes, _ := json.Marshal(bean)

	ent := &nekokfmt.ProxyEntity{
		Type: "shadowsocks",
		Id:   2,
		Bean: beanBytes,
	}
	routing := &nekokfmt.Routing{DefOutbound: "proxy"}
	ds := &nekokfmt.DataStore{LogLevel: "warn"}

	result := BuildConfig(ent, nil, routing, ds, true, false)
	if result.Error != "" {
		t.Fatalf("BuildConfig error: %s", result.Error)
	}

	configStr := prettyJSON(t, result.CoreConfig)
	// normalize spaces for substring matching
	configFlat := strings.ReplaceAll(configStr, " ", "")
	if !strings.Contains(configFlat, `"type":"shadowsocks"`) {
		t.Errorf("config missing shadowsocks outbound:\n%s", configStr)
	}
	if !strings.Contains(configFlat, `"method":"aes-256-gcm"`) {
		t.Errorf("config missing method:\n%s", configStr)
	}
}

// TestBuildTrojanConfig verifies a Trojan profile with TLS.
func TestBuildTrojanConfig(t *testing.T) {
	stream := &nekokfmt.V2RayStreamSettings{
		Network:  "tcp",
		Security: "tls",
		Sni:      "example.com",
	}
	bean := &nekokfmt.TrojanVLESSBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "9.10.11.12",
			ServerPort:    443,
		},
		Password:  "trojan-pass",
		ProxyType: nekokfmt.TrojanVLESSProxyTrojan,
		Stream:    stream,
	}
	beanBytes, _ := json.Marshal(bean)

	ent := &nekokfmt.ProxyEntity{Type: "trojan", Id: 3, Bean: beanBytes}
	routing := &nekokfmt.Routing{DefOutbound: "proxy"}
	ds := &nekokfmt.DataStore{LogLevel: "info"}

	result := BuildConfig(ent, nil, routing, ds, false, false)
	if result.Error != "" {
		t.Fatalf("BuildConfig error: %s", result.Error)
	}

	configStr := prettyJSON(t, result.CoreConfig)
	configFlat := strings.ReplaceAll(configStr, " ", "")
	if !strings.Contains(configFlat, `"type":"trojan"`) {
		t.Errorf("config missing trojan outbound:\n%s", configStr)
	}
	if !strings.Contains(configFlat, `"server_name":"example.com"`) {
		t.Errorf("config missing tls sni:\n%s", configStr)
	}
}

func prettyJSON(t *testing.T, v interface{}) string {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		t.Fatalf("pretty json: %v", err)
	}
	return string(b)
}

func TestBuildNaiveOutbound(t *testing.T) {
	bean := &nekokfmt.NaiveBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "naive.example.com",
			ServerPort:    443,
			Name:          "naive-test",
		},
		Username:      "user1",
		Password:      "pass1",
		Sni:           "naive.example.com",
		AllowInsecure: false,
	}
	out, err := BuildOutboundSingBox(bean)
	if err != nil {
		t.Fatalf("build error: %v", err)
	}
	if out["type"] != "naive" {
		t.Errorf("expected type naive, got %v", out["type"])
	}
	if out["username"] != "user1" {
		t.Errorf("expected username user1, got %v", out["username"])
	}
	tls, ok := out["tls"].(map[string]interface{})
	if !ok {
		t.Fatalf("expected tls map, got %T", out["tls"])
	}
	if tls["server_name"] != "naive.example.com" {
		t.Errorf("expected sni, got %v", tls["server_name"])
	}
}

func TestBuildAnyTLSOutbound(t *testing.T) {
	bean := &nekokfmt.AnyTLSBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "anytls.example.com",
			ServerPort:    443,
			Name:          "anytls-test",
		},
		Password:       "secret",
		Sni:            "anytls.example.com",
		MinIdleSession: 5,
	}
	out, err := BuildOutboundSingBox(bean)
	if err != nil {
		t.Fatalf("build error: %v", err)
	}
	if out["type"] != "anytls" {
		t.Errorf("expected type anytls, got %v", out["type"])
	}
	if out["password"] != "secret" {
		t.Errorf("expected password secret, got %v", out["password"])
	}
	if out["min_idle_session"] != 5 {
		t.Errorf("expected min_idle_session 5, got %v", out["min_idle_session"])
	}
}

func TestBuildSSHOutbound(t *testing.T) {
	bean := &nekokfmt.SSHBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "ssh.example.com",
			ServerPort:    22,
			Name:          "ssh-test",
		},
		User:     "root",
		Password: "toor",
	}
	out, err := BuildOutboundSingBox(bean)
	if err != nil {
		t.Fatalf("build error: %v", err)
	}
	if out["type"] != "ssh" {
		t.Errorf("expected type ssh, got %v", out["type"])
	}
	if out["user"] != "root" {
		t.Errorf("expected user root, got %v", out["user"])
	}
}

func TestBuildWireGuardOutbound(t *testing.T) {
	bean := &nekokfmt.WireGuardBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "wg.example.com",
			ServerPort:    51820,
			Name:          "wg-test",
		},
		PrivateKey:     "abc123",
		Address:        "10.0.0.2/32",
		MTU:            1280,
		PeerPublicKey:  "pubkey",
		PeerAllowedIPs: "0.0.0.0/0,::/0",
		PeerKeepAlive:  25,
		PeerReserved:   "0,0,0",
	}
	out, err := BuildOutboundSingBox(bean)
	if err != nil {
		t.Fatalf("build error: %v", err)
	}
	if out["type"] != "wireguard" {
		t.Errorf("expected type wireguard, got %v", out["type"])
	}
	if out["private_key"] != "abc123" {
		t.Errorf("expected private_key abc123, got %v", out["private_key"])
	}
	peers, ok := out["peers"].([]interface{})
	if !ok || len(peers) == 0 {
		t.Fatalf("expected peers array, got %T", out["peers"])
	}
	peer := peers[0].(map[string]interface{})
	if peer["public_key"] != "pubkey" {
		t.Errorf("expected public_key pubkey, got %v", peer["public_key"])
	}
	allowed := peer["allowed_ips"].([]string)
	if len(allowed) != 2 || allowed[0] != "0.0.0.0/0" || allowed[1] != "::/0" {
		t.Errorf("unexpected allowed_ips: %v", allowed)
	}
	reserved := peer["reserved"].([]uint8)
	if len(reserved) != 3 || reserved[0] != 0 {
		t.Errorf("unexpected reserved: %v", reserved)
	}
}

// TestBuildTunInboundUsesModernAddressField guards against the sing-box 1.12+
// removal of legacy tun address fields: emitting inet4_address/inet6_address
// aborts startup with "legacy tun address fields are deprecated in sing-box
// 1.10.0 and removed in sing-box 1.12.0".
func TestBuildTunInboundUsesModernAddressField(t *testing.T) {
	bean := &nekokfmt.ShadowSocksBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "5.6.7.8",
			ServerPort:    8388,
		},
		Method:   "aes-256-gcm",
		Password: "secret",
	}
	beanBytes, _ := json.Marshal(bean)

	ent := &nekokfmt.ProxyEntity{
		Type: "shadowsocks",
		Id:   3,
		Bean: beanBytes,
	}
	routing := &nekokfmt.Routing{DefOutbound: "proxy"}
	ds := &nekokfmt.DataStore{
		LogLevel:             "info",
		InboundAddress:       "127.0.0.1",
		InboundSocksPort:     2080,
		SpmodeVPN:            true,
		VPNInternalTun:       true,
		VPNMTU:               0, // zero must fall back, never reach the config
		CoreBoxUnderlyingDNS: "local",
	}

	result := BuildConfig(ent, nil, routing, ds, false, false)
	if result.Error != "" {
		t.Fatalf("BuildConfig error: %s", result.Error)
	}

	configFlat := strings.ReplaceAll(prettyJSON(t, result.CoreConfig), " ", "")
	configFlat = strings.ReplaceAll(configFlat, "\n", "")
	configFlat = strings.ReplaceAll(configFlat, "\t", "")
	if !strings.Contains(configFlat, `"type":"tun"`) {
		t.Fatalf("config missing tun inbound:\n%s", prettyJSON(t, result.CoreConfig))
	}
	for _, legacy := range []string{
		"inet4_address", "inet6_address",
		"inet4_route_address", "inet6_route_address",
		"endpoint_independent_nat",
	} {
		if strings.Contains(configFlat, `"`+legacy+`"`) {
			t.Errorf("config contains removed legacy tun field %q", legacy)
		}
	}
	if !strings.Contains(configFlat, `"address":["172.19.0.1/28"]`) {
		t.Errorf("tun inbound missing modern address list:\n%s", prettyJSON(t, result.CoreConfig))
	}
	if !strings.Contains(configFlat, `"mtu":1500`) {
		t.Errorf("tun inbound missing MTU fallback:\n%s", prettyJSON(t, result.CoreConfig))
	}
}

func TestBuildTunInboundWithFileDescriptor(t *testing.T) {
	bean := &nekokfmt.ShadowSocksBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "5.6.7.8",
			ServerPort:    8388,
		},
		Method:   "aes-256-gcm",
		Password: "secret",
	}
	beanBytes, _ := json.Marshal(bean)

	ent := &nekokfmt.ProxyEntity{
		Type: "shadowsocks",
		Id:   3,
		Bean: beanBytes,
	}
	routing := &nekokfmt.Routing{DefOutbound: "proxy"}
	ds := &nekokfmt.DataStore{
		LogLevel:             "info",
		InboundAddress:       "127.0.0.1",
		InboundSocksPort:     2080,
		SpmodeVPN:            true,
		VPNInternalTun:       true,
		VPNMTU:               1500,
		VPNTunFd:             42,
		CoreBoxUnderlyingDNS: "local",
	}

	result := BuildConfig(ent, nil, routing, ds, false, false)
	if result.Error != "" {
		t.Fatalf("BuildConfig error: %s", result.Error)
	}

	configFlat := strings.ReplaceAll(prettyJSON(t, result.CoreConfig), " ", "")
	configFlat = strings.ReplaceAll(configFlat, "\n", "")
	configFlat = strings.ReplaceAll(configFlat, "\t", "")

	if !strings.Contains(configFlat, `"file_descriptor":42`) {
		t.Fatalf("config missing file_descriptor:42:\n%s", prettyJSON(t, result.CoreConfig))
	}
	if !strings.Contains(configFlat, `"auto_route":false`) {
		t.Fatalf("config should have auto_route:false for external tun fd:\n%s", prettyJSON(t, result.CoreConfig))
	}
	if strings.Contains(configFlat, `"interface_name"`) {
		t.Fatalf("config should not contain interface_name when file_descriptor is set:\n%s", prettyJSON(t, result.CoreConfig))
	}
}

// TestBuildEnablesV2RayStats guards the dashboard traffic graph: without the
// v2ray_api stats service, outbound counters are never created and every
// QueryStats call reports 0, leaving up/down rates permanently at zero.
func TestBuildEnablesV2RayStats(t *testing.T) {
	bean, _ := json.Marshal(&nekokfmt.ShadowSocksBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "5.6.7.8",
			ServerPort:    8388,
		},
		Method:   "aes-256-gcm",
		Password: "secret",
	})
	ent := &nekokfmt.ProxyEntity{Type: "shadowsocks", Id: 4, Bean: bean}
	routing := &nekokfmt.Routing{DefOutbound: "proxy"}
	ds := &nekokfmt.DataStore{
		LogLevel:             "info",
		InboundAddress:       "127.0.0.1",
		InboundSocksPort:     2080,
		CoreBoxUnderlyingDNS: "local",
	}

	result := BuildConfig(ent, nil, routing, ds, false, false)
	if result.Error != "" {
		t.Fatalf("BuildConfig error: %s", result.Error)
	}
	configFlat := strings.ReplaceAll(prettyJSON(t, result.CoreConfig), " ", "")
	configFlat = strings.ReplaceAll(configFlat, "\n", "")
	if !strings.Contains(configFlat, `"v2ray_api"`) {
		t.Errorf("config missing experimental.v2ray_api:\n%s", prettyJSON(t, result.CoreConfig))
	}
	if !strings.Contains(configFlat, `"enabled":true`) {
		t.Errorf("v2ray stats not enabled:\n%s", prettyJSON(t, result.CoreConfig))
	}
	if !strings.Contains(configFlat, `"outbounds":["proxy"]`) {
		t.Errorf("v2ray stats missing proxy outbound:\n%s", prettyJSON(t, result.CoreConfig))
	}

	// Test configs must stay minimal: no listeners, no stats server.
	testResult := BuildConfig(ent, nil, routing, ds, true, false)
	if testResult.Error != "" {
		t.Fatalf("BuildConfig(forTest) error: %s", testResult.Error)
	}
	testFlat := strings.ReplaceAll(prettyJSON(t, testResult.CoreConfig), " ", "")
	if strings.Contains(testFlat, `"v2ray_api"`) {
		t.Errorf("forTest config should not carry a v2ray_api listener")
	}
}
