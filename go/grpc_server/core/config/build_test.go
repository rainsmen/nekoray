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
		Type:    "vmess",
		Id:      1,
		Gid:     1,
		Bean:    beanBytes,
	}
	routing := &nekokfmt.Routing{
		DefOutbound: "proxy",
		SniffingMode: nekokfmt.SniffingModeForRouting,
	}
	ds := &nekokfmt.DataStore{
		InboundAddress:    "127.0.0.1",
		InboundSocksPort:  2080,
		LogLevel:          "info",
		MuxConcurrency:    0,
		CoreBoxClashAPI:   0,
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
	if !strings.Contains(configStr, `"type":"shadowsocks"`) {
		t.Errorf("config missing shadowsocks outbound:\n%s", configStr)
	}
	if !strings.Contains(configStr, `"method":"aes-256-gcm"`) {
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
	if !strings.Contains(configStr, `"type":"trojan"`) {
		t.Errorf("config missing trojan outbound:\n%s", configStr)
	}
	if !strings.Contains(configStr, `"server_name":"example.com"`) {
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
