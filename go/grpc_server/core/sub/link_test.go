package sub

import (
	"encoding/json"
	"strings"
	"testing"

	nekokfmt "grpc_server/core/fmt"
)

func TestParseVMessLink(t *testing.T) {
	link := "vmess://eyJ2IjoiMiIsInBzIjoidGVzdCIsImFkZCI6IjEuMi4zLjQiLCJwb3J0Ijo0NDMsImlkIjoiYWJjZGVmZy1oaWota2xt LW5vcC1xcnN0IiwiYWlkIjowLCJuZXQiOiJ3cyIsInBhdGgiOiIvd3MiLCJob3N0IjoiZXhhbXBsZS5jb20iLCJ0bHMiOiJ0bHMiLCJzY3kiOiJhdXRvIn0="
	// strip spaces (added for readability)
	link = strings.ReplaceAll(link, " ", "")
	r := ParseLink(link)
	if r.Error != "" {
		t.Fatalf("parse error: %s", r.Error)
	}
	if r.Profile.Type != "vmess" {
		t.Errorf("expected type vmess, got %s", r.Profile.Type)
	}
	bean, err := r.Profile.DecodeBean()
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	b := bean.(*nekokfmt.VMessBean)
	if b.ServerAddress != "1.2.3.4" {
		t.Errorf("expected server 1.2.3.4, got %s", b.ServerAddress)
	}
	if b.ServerPort != 443 {
		t.Errorf("expected port 443, got %d", b.ServerPort)
	}
	if b.Stream.Network != "ws" {
		t.Errorf("expected network ws, got %s", b.Stream.Network)
	}
}

func TestParseVLESSLink(t *testing.T) {
	link := "vless://abc-def-123@1.2.3.4:443?type=ws&security=tls&sni=example.com&path=%2Fws&host=example.com&flow=xtls-rprx-vision#myname"
	r := ParseLink(link)
	if r.Error != "" {
		t.Fatalf("parse error: %s", r.Error)
	}
	if r.Profile.Type != "vless" {
		t.Errorf("expected type vless, got %s", r.Profile.Type)
	}
	bean, _ := r.Profile.DecodeBean()
	b := bean.(*nekokfmt.TrojanVLESSBean)
	if b.ServerAddress != "1.2.3.4" {
		t.Errorf("expected server 1.2.3.4, got %s", b.ServerAddress)
	}
	if b.Password != "abc-def-123" {
		t.Errorf("expected uuid abc-def-123, got %s", b.Password)
	}
	if b.Stream.Network != "ws" {
		t.Errorf("expected network ws, got %s", b.Stream.Network)
	}
	if b.Flow != "xtls-rprx-vision" {
		t.Errorf("expected flow, got %s", b.Flow)
	}
	if b.Name != "myname" {
		t.Errorf("expected name myname, got %s", b.Name)
	}
}

func TestParseShadowsocksLink(t *testing.T) {
	// standard format: ss://base64(method:password)@host:port
	link := "ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@1.2.3.4:8388#test-ss"
	r := ParseLink(link)
	if r.Error != "" {
		t.Fatalf("parse error: %s", r.Error)
	}
	if r.Profile.Type != "shadowsocks" {
		t.Errorf("expected type shadowsocks, got %s", r.Profile.Type)
	}
	bean, _ := r.Profile.DecodeBean()
	b := bean.(*nekokfmt.ShadowSocksBean)
	if b.Method != "aes-256-gcm" {
		t.Errorf("expected method aes-256-gcm, got %s", b.Method)
	}
	if b.Password != "password" {
		t.Errorf("expected password password, got %s", b.Password)
	}
}

func TestParseTrojanLink(t *testing.T) {
	link := "trojan://password123@1.2.3.4:443?type=tcp&security=tls&sni=example.com#trojan-test"
	r := ParseLink(link)
	if r.Error != "" {
		t.Fatalf("parse error: %s", r.Error)
	}
	if r.Profile.Type != "trojan" {
		t.Errorf("expected type trojan, got %s", r.Profile.Type)
	}
	bean, _ := r.Profile.DecodeBean()
	b := bean.(*nekokfmt.TrojanVLESSBean)
	if b.Password != "password123" {
		t.Errorf("expected password password123, got %s", b.Password)
	}
}

func TestParseHysteria2Link(t *testing.T) {
	link := "hysteria2://pass123@1.2.3.4:443?sni=example.com&insecure=1#hy2"
	r := ParseLink(link)
	if r.Error != "" {
		t.Fatalf("parse error: %s", r.Error)
	}
	if r.Profile.Type != "hysteria2" {
		t.Errorf("expected type hysteria2, got %s", r.Profile.Type)
	}
	bean, _ := r.Profile.DecodeBean()
	b := bean.(*nekokfmt.QUICBean)
	if b.Password != "pass123" {
		t.Errorf("expected password pass123, got %s", b.Password)
	}
	if !b.AllowInsecure {
		t.Errorf("expected allowInsecure true")
	}
}

func TestParseTUICLink(t *testing.T) {
	link := "tuic://uuid-123:pass456@1.2.3.4:443?sni=example.com&congestion_control=bbr"
	r := ParseLink(link)
	if r.Error != "" {
		t.Fatalf("parse error: %s", r.Error)
	}
	if r.Profile.Type != "tuic" {
		t.Errorf("expected type tuic, got %s", r.Profile.Type)
	}
	bean, _ := r.Profile.DecodeBean()
	b := bean.(*nekokfmt.QUICBean)
	if b.Uuid != "uuid-123" {
		t.Errorf("expected uuid uuid-123, got %s", b.Uuid)
	}
	if b.Password != "pass456" {
		t.Errorf("expected password pass456, got %s", b.Password)
	}
}

func TestParseContentRaw(t *testing.T) {
	content := "vless://abc@1.2.3.4:443?type=tcp&security=tls#node1\n" +
		"trojan://pass@5.6.7.8:443?type=tcp#node2\n"
	results := ParseContent(content, "auto")
	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}
	if results[0].Profile.Type != "vless" {
		t.Errorf("expected first vless, got %s", results[0].Profile.Type)
	}
	if results[1].Profile.Type != "trojan" {
		t.Errorf("expected second trojan, got %s", results[1].Profile.Type)
	}
}

func TestParseClash(t *testing.T) {
	content := `
proxies:
  - name: "test-vmess"
    type: vmess
    server: 1.2.3.4
    port: 443
    uuid: test-uuid
    alterId: 0
    cipher: auto
    network: ws
    tls: true
   servername: example.com
    ws-opts:
      path: /ws
      headers:
        Host: example.com
  - name: "test-ss"
    type: ss
    server: 5.6.7.8
    port: 8388
    cipher: aes-256-gcm
    password: secret
`
	results := ParseContent(content, "auto")
	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}
	if results[0].Profile.Type != "vmess" {
		t.Errorf("expected first vmess, got %s", results[0].Profile.Type)
	}
	bean0, _ := results[0].Profile.DecodeBean()
	b0 := bean0.(*nekokfmt.VMessBean)
	if b0.Stream.Network != "ws" {
		t.Errorf("expected network ws, got %s", b0.Stream.Network)
	}
	if b0.Stream.Security != "tls" {
		t.Errorf("expected security tls, got %s", b0.Stream.Security)
	}
	if results[1].Profile.Type != "shadowsocks" {
		t.Errorf("expected second shadowsocks, got %s", results[1].Profile.Type)
	}
}

func TestGenerateVLESSLink(t *testing.T) {
	bean := &nekokfmt.TrojanVLESSBean{
		AbstractBean: nekokfmt.AbstractBean{
			Name:          "test",
			ServerAddress: "1.2.3.4",
			ServerPort:    443,
		},
		Password:  "abc-uuid",
		ProxyType: nekokfmt.TrojanVLESSProxyVLESS,
		Flow:      "xtls-rprx-vision",
		Stream: &nekokfmt.V2RayStreamSettings{
			Network:  "ws",
			Security: "tls",
			Sni:      "example.com",
			Path:      "/ws",
			Host:      "example.com",
		},
	}
	ent := newEntity("vless", bean)
	link, err := GenerateLink(ent, "v2rayn")
	if err != nil {
		t.Fatalf("generate error: %v", err)
	}
	if !strings.HasPrefix(link, "vless://") {
		t.Errorf("expected vless:// prefix, got %s", link)
	}
	if !strings.Contains(link, "type=ws") {
		t.Errorf("expected type=ws in link: %s", link)
	}
	if !strings.Contains(link, "security=tls") {
		t.Errorf("expected security=tls in link: %s", link)
	}
	if !strings.Contains(link, "flow=xtls-rprx-vision") {
		t.Errorf("expected flow in link: %s", link)
	}
}

func TestProfileFilterUniq(t *testing.T) {
	bean1 := &nekokfmt.VMessBean{
		AbstractBean: nekokfmt.AbstractBean{ServerAddress: "1.2.3.4", ServerPort: 443},
		Uuid:         "uuid-1",
	}
	bean2 := &nekokfmt.VMessBean{
		AbstractBean: nekokfmt.AbstractBean{ServerAddress: "1.2.3.4", ServerPort: 443},
		Uuid:         "uuid-2",
	}
	bean3 := &nekokfmt.VMessBean{
		AbstractBean: nekokfmt.AbstractBean{ServerAddress: "5.6.7.8", ServerPort: 443},
		Uuid:         "uuid-3",
	}
	e1 := newEntity("vmess", bean1)
	e2 := newEntity("vmess", bean2)
	e3 := newEntity("vmess", bean3)

	// by address: e1 and e2 have same address -> dedup
	out := ProfileFilter{}.Uniq([]*nekokfmt.ProxyEntity{e1, e2, e3}, true, false)
	if len(out) != 2 {
		t.Errorf("expected 2 after dedup by address, got %d", len(out))
	}

	// by full bean: all 3 unique (different uuid)
	out = ProfileFilter{}.Uniq([]*nekokfmt.ProxyEntity{e1, e2, e3}, false, false)
	if len(out) != 3 {
		t.Errorf("expected 3 unique by bean, got %d", len(out))
	}
}

func TestParseSIP008(t *testing.T) {
	content := `{"servers":[{"id":1,"remarks":"sip008-test","server":"1.2.3.4","server_port":8388,"method":"aes-256-gcm","password":"pw"}]}`
	results := ParseContent(content, "sip008")
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	if results[0].Profile.Type != "shadowsocks" {
		t.Errorf("expected shadowsocks, got %s", results[0].Profile.Type)
	}
	bean, _ := results[0].Profile.DecodeBean()
	b := bean.(*nekokfmt.ShadowSocksBean)
	if b.ServerAddress != "1.2.3.4" {
		t.Errorf("expected server 1.2.3.4, got %s", b.ServerAddress)
	}
}

// ensure ProxyEntity json roundtrip
func TestEntityRoundtrip(t *testing.T) {
	bean := &nekokfmt.VMessBean{
		AbstractBean: nekokfmt.AbstractBean{Name: "x", ServerAddress: "1.1.1.1", ServerPort: 80},
		Uuid:         "u",
	}
	ent := newEntity("vmess", bean)
	b, _ := json.Marshal(ent)
	var ent2 nekokfmt.ProxyEntity
	json.Unmarshal(b, &ent2)
	if ent2.Type != "vmess" {
		t.Errorf("roundtrip type mismatch")
	}
}
