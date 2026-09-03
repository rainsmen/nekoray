package main

import (
	"context"
	"encoding/json"
	"testing"

	"grpc_server/core/config"
	nekokfmt "grpc_server/core/fmt"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
)

// TestTunInboundInitializes reproduces the user-facing startup failure
// "initialize inbound[1]: legacy tun address fields are deprecated in
// sing-box 1.10.0 and removed in sing-box 1.12.0".
//
// It builds a TUN-enabled config through the real ConfigBuilder and runs it
// through sing-box instance construction (box.New validates inbound
// options). Start is deliberately skipped so the test needs no privileges
// and no /dev/net/tun.
func TestTunInboundInitializes(t *testing.T) {
	bean, _ := json.Marshal(&nekokfmt.ShadowSocksBean{
		AbstractBean: nekokfmt.AbstractBean{
			ServerAddress: "5.6.7.8",
			ServerPort:    8388,
		},
		Method:   "aes-256-gcm",
		Password: "secret",
	})
	ent := &nekokfmt.ProxyEntity{Type: "shadowsocks", Id: 99, Bean: bean}
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
		LogLevel:             "info",
		InboundAddress:       "127.0.0.1",
		InboundSocksPort:     2080,
		SpmodeVPN:            true,
		VPNInternalTun:       true,
		CoreBoxUnderlyingDNS: "local",
	}

	result := config.BuildConfig(ent, nil, routing, ds, false, false)
	if result.Error != "" {
		t.Fatalf("BuildConfig error: %s", result.Error)
	}
	configBytes, err := json.Marshal(result.CoreConfig)
	if err != nil {
		t.Fatalf("marshal config: %v", err)
	}

	boxCtx := include.Context(context.Background())
	var options option.Options
	if err := options.UnmarshalJSONContext(boxCtx, configBytes); err != nil {
		t.Fatalf("config rejected by sing-box options: %v", err)
	}

	ctx, cancel := context.WithCancel(boxCtx)
	defer cancel()
	inst, err := box.New(box.Options{Context: ctx, Options: options})
	if err != nil {
		t.Fatalf("box.New with TUN inbound failed: %v\nConfig:\n%s", err, string(configBytes))
	}
	inst.Close()
}
