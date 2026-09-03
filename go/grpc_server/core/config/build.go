// Package config implements the sing-box config builder, mirroring the C++
// db/ConfigBuilder.cpp so config generation can run inside nekobox_core.
//
// This is the phase-1 "ConfigBuilder sink-down": the GUI sends serialized
// profile/group/routing/datastore data, and core returns the full sing-box
// config JSON.
package config

import (
	"encoding/json"
	"fmt"
	"strings"

	nekokfmt "grpc_server/core/fmt"
)

// BuildResult mirrors NekoGui::BuildConfigResult.
type BuildResult struct {
	CoreConfig    map[string]interface{}
	OutboundStats []OutboundStat
	ExtResults    []ExternalBuildResult
	Error         string
}

// OutboundStat tracks a tag for traffic stats.
type OutboundStat struct {
	Id  int
	Tag string
}

// ExternalBuildResult mirrors NekoGui_fmt::ExternalBuildResult.
type ExternalBuildResult struct {
	Program      string
	Env          []string
	Arguments    []string
	Tag          string
	Error        string
	ConfigExport string
}

// BuildStatus tracks the in-progress build state.
type BuildStatus struct {
	Ent                 *nekokfmt.ProxyEntity
	Group               *nekokfmt.Group
	Routing             *nekokfmt.Routing
	DataStore           *nekokfmt.DataStore
	ForTest             bool
	ForExport           bool
	GlobalProfiles      map[int]bool
	Outbounds           []map[string]interface{}
	Inbounds            []map[string]interface{}
	Endpoints           []map[string]interface{}
	RoutingRules        []map[string]interface{}
	IgnoreConnTag       []string
	DomainListDNSRemote []string
	DomainListDNSDirect []string
	DomainListRemote    []string
	DomainListDirect    []string
	DomainListBlock     []string
	IPListRemote        []string
	IPListDirect        []string
	IPListBlock         []string
}

// BuildConfig is the entry point, mirroring NekoGui::BuildConfig.
//
// It takes the serialized profile/group/routing/datastore and produces the
// full sing-box config. Custom bean with core="internal-full" bypasses the
// builder and uses the bean's own config.
func BuildConfig(ent *nekokfmt.ProxyEntity, group *nekokfmt.Group, routing *nekokfmt.Routing, ds *nekokfmt.DataStore, forTest, forExport bool) *BuildResult {
	result := &BuildResult{
		CoreConfig: map[string]interface{}{},
	}
	status := &BuildStatus{
		Ent:            ent,
		Group:          group,
		Routing:        routing,
		DataStore:      ds,
		ForTest:        forTest,
		ForExport:      forExport,
		GlobalProfiles: map[int]bool{},
	}

	// Custom bean with core="internal-full" uses the bean's config directly.
	if ent != nil && ent.Type == string(nekokfmt.BeanCustom) {
		var cb nekokfmt.CustomBean
		if err := json.Unmarshal(ent.Bean, &cb); err == nil && cb.Core == "internal-full" {
			var raw map[string]interface{}
			if err := json.Unmarshal([]byte(cb.ConfigSimple), &raw); err != nil {
				result.Error = fmt.Sprintf("invalid internal-full config: %v", err)
				return result
			}
			result.CoreConfig = raw
			return result
		}
	}

	BuildConfigSingBox(status, result)

	// apply custom outbound config from bean
	// (MergeJson of bean.custom_outbound into the proxy outbound)
	return result
}

// splitLinesSkipSharp mirrors SplitLinesSkipSharp: split by newline, trim
// whitespace, skip empty lines and lines starting with '#'.
func splitLinesSkipSharp(s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		out = append(out, line)
	}
	return out
}

// BuildConfigSingBox mirrors NekoGui::BuildConfigSingBox.
//
// This is a large function; for phase-1 MVP we implement the core structure
// (log, inbounds, outbounds, dns, route) and defer chain/external support.
func BuildConfigSingBox(status *BuildStatus, result *BuildResult) {
	ds := status.DataStore
	routing := status.Routing

	// Log
	result.CoreConfig["log"] = map[string]interface{}{
		"level": ds.LogLevel,
	}

	// Inbounds: mixed-in (skip for test)
	if isValidPort(ds.InboundSocksPort) && !status.ForTest {
		inbound := map[string]interface{}{
			"tag":         "mixed-in",
			"type":        "mixed",
			"listen":      ds.InboundAddress,
			"listen_port": ds.InboundSocksPort,
		}
		if ds.InboundAuthUsername != "" && ds.InboundAuthPassword != "" {
			inbound["users"] = []map[string]interface{}{
				{
					"username": ds.InboundAuthUsername,
					"password": ds.InboundAuthPassword,
				},
			}
		}
		status.Inbounds = append(status.Inbounds, inbound)
	}

	// TUN inbound (VPN mode)
	if ds.VPNInternalTun && ds.SpmodeVPN && !status.ForTest {
		// The Flutter client used to omit TUN keys from the datastore payload,
		// leaving MTU at its Go zero-value (0) and failing inbound creation
		// in sing-box. Guard here as well so a zero MTU can never reach the
		// core config.
		mtu := ds.VPNMTU
		if mtu <= 0 || mtu > 9000 {
			mtu = 1500
		}
		// sing-box >= 1.12 removed the legacy tun address fields
		// (inet4_address/inet6_address, endpoint_independent_nat): emitting
		// them aborts startup with "legacy tun address fields are deprecated
		// ...". The merged replacement is the `address` list.
		address := []string{"172.19.0.1/28"}
		if ds.VPNIPv6 {
			address = append(address, "fdfe:dcba:9876::1/126")
		}
		inbound := map[string]interface{}{
			"tag":            "tun-in",
			"type":           "tun",
			"interface_name": genTunName(),
			"address":        address,
			"auto_route":     true,
			"mtu":            mtu,
			"stack":          vpnImplementation(ds.VPNImplementation),
			"strict_route":   ds.VPNStrictRoute,
		}
		status.Inbounds = append(status.Inbounds, inbound)
	}

	// Outbounds (chain / single)
	tagProxy := buildChain(status, result)
	if result.Error != "" {
		return
	}

	// direct / bypass / block
	status.Outbounds = append(status.Outbounds,
		map[string]interface{}{"type": "direct", "tag": "direct"},
		map[string]interface{}{"type": "direct", "tag": "bypass"},
		map[string]interface{}{"type": "block", "tag": "block"},
	)

	// custom inbounds
	if !status.ForTest && ds.CustomInbound != "" {
		var ci map[string]interface{}
		if err := json.Unmarshal([]byte(ds.CustomInbound), &ci); err == nil {
			if arr, ok := ci["inbounds"].([]interface{}); ok {
				for _, ib := range arr {
					if m, ok := ib.(map[string]interface{}); ok {
						status.Inbounds = append(status.Inbounds, m)
					}
				}
			}
		}
	}

	result.CoreConfig["inbounds"] = status.Inbounds
	result.CoreConfig["outbounds"] = status.Outbounds
	if len(status.Endpoints) > 0 {
		result.CoreConfig["endpoints"] = status.Endpoints
	}

	// user rules
	if !status.ForTest {
		for _, line := range splitLinesSkipSharp(routing.ProxyDomain) {
			if routing.DNSRouting {
				status.DomainListDNSRemote = append(status.DomainListDNSRemote, line)
			}
			status.DomainListRemote = append(status.DomainListRemote, line)
		}
		for _, line := range splitLinesSkipSharp(routing.DirectDomain) {
			if routing.DNSRouting {
				status.DomainListDNSDirect = append(status.DomainListDNSDirect, line)
			}
			status.DomainListDirect = append(status.DomainListDirect, line)
		}
		for _, line := range splitLinesSkipSharp(routing.BlockDomain) {
			status.DomainListBlock = append(status.DomainListBlock, line)
		}
		for _, line := range splitLinesSkipSharp(routing.BlockIP) {
			status.IPListBlock = append(status.IPListBlock, line)
		}
		for _, line := range splitLinesSkipSharp(routing.ProxyIP) {
			status.IPListRemote = append(status.IPListRemote, line)
		}
		for _, line := range splitLinesSkipSharp(routing.DirectIP) {
			status.IPListDirect = append(status.IPListDirect, line)
		}
	}

	// DNS
	buildDNS(status, result)

	// Routing
	buildRoute(status, result, tagProxy)

	// Experimental (clash api)
	if !status.ForTest && ds.CoreBoxClashAPI > 0 {
		result.CoreConfig["experimental"] = map[string]interface{}{
			"clash_api": map[string]interface{}{
				"external_controller": fmt.Sprintf("127.0.0.1:%d", ds.CoreBoxClashAPI),
				"secret":              ds.CoreBoxClashAPISecret,
				"external_ui":         "dashboard",
			},
		}
	}
}

func isValidPort(p int) bool {
	return p > 0 && p < 65536
}

func genTunName() string {
	return "neko-tun"
}

func vpnImplementation(idx int) string {
	impls := []string{"gvisor", "system", "mixed"}
	if idx >= 0 && idx < len(impls) {
		return impls[idx]
	}
	return "gvisor"
}
