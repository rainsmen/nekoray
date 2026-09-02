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
