package config

import (
	"encoding/json"
	"fmt"
	"net"
	"strings"

	nekokfmt "grpc_server/core/fmt"
)

// buildChain mirrors NekoGui::BuildChain / BuildChainInternal.
//
// For phase-1 MVP we implement single-profile (non-chain) building. Chain
// support (front_proxy, multi-hop) is deferred.
func buildChain(status *BuildStatus, result *BuildResult) string {
	ent := status.Ent
	tagOut := "proxy"

	// determine if external core is needed (phase-1: always internal)
	externalStat := 0

	// decode bean
	bean, err := ent.DecodeBean()
	if err != nil {
		result.Error = err.Error()
		return ""
	}

	// build outbound
	var outbound map[string]interface{}
	if externalStat > 0 {
		// external core support deferred (phase-1 MVP)
		result.Error = "external core not yet supported in Go core (phase-1 MVP)"
		return ""
	}

	outbound, err = BuildOutboundSingBox(bean)
	if err != nil {
		result.Error = err.Error()
		return ""
	}

	// outbound misc
	outbound["tag"] = tagOut
	result.OutboundStats = append(result.OutboundStats, OutboundStat{
		Id:  ent.Id,
		Tag: tagOut,
	})

	// mux (vmess/trojan/vless)
	stream := getStreamSettings(bean)
	needMux := (ent.Type == "vmess" || ent.Type == "trojan" || ent.Type == "vless") && status.DataStore.MuxConcurrency > 0
	if stream != nil {
		if stream.Network == "grpc" || stream.Network == "quic" || (stream.Network == "http" && stream.Security == "tls") {
			needMux = false
		}
		switch stream.MultiplexStatus {
		case 0:
			if !status.DataStore.MuxDefaultOn {
				needMux = false
			}
		case 1:
			needMux = true
		case 2:
			needMux = false
		}
	}
	if ent.Type == "vless" && outbound["flow"] != "" && outbound["flow"] != nil {
		needMux = false
	}

	// domain_strategy (skip for wireguard which does not support it)
	if status.Routing.OutboundDomainStrategy != "" && ent.Type != "wireguard" {
		outbound["domain_strategy"] = status.Routing.OutboundDomainStrategy
	}

	// mux
	if needMux {
		outbound["multiplex"] = map[string]interface{}{
			"enabled":     true,
			"protocol":    status.DataStore.MuxProtocol,
			"padding":     status.DataStore.MuxPadding,
			"max_streams": status.DataStore.MuxConcurrency,
		}
	}

	// apply custom_outbound from bean if present
	if raw := getCustomOutbound(ent); raw != "" {
		var custom map[string]interface{}
		if err := json.Unmarshal([]byte(raw), &custom); err == nil {
			for k, v := range custom {
				outbound[k] = v
			}
		}
	}

	// bypass lookup for first profile
	serverAddr := strings.TrimSpace(getServerAddress(bean))
	if serverAddr != "" && !isIPAddress(serverAddr) {
		status.DomainListDNSDirect = append(status.DomainListDNSDirect, "full:"+serverAddr)
	}

	if ent.Type == "wireguard" {
		status.Endpoints = append(status.Endpoints, outbound)
	} else {
		status.Outbounds = append(status.Outbounds, outbound)
	}
	return tagOut
}

func getStreamSettings(bean interface{}) *nekokfmt.V2RayStreamSettings {
	switch b := bean.(type) {
	case *nekokfmt.SocksHttpBean:
		return b.Stream
	case *nekokfmt.ShadowSocksBean:
		return b.Stream
	case *nekokfmt.VMessBean:
		return b.Stream
	case *nekokfmt.TrojanVLESSBean:
		return b.Stream
	}
	return nil
}

func getServerAddress(bean interface{}) string {
	switch b := bean.(type) {
	case *nekokfmt.SocksHttpBean:
		return b.ServerAddress
	case *nekokfmt.ShadowSocksBean:
		return b.ServerAddress
	case *nekokfmt.VMessBean:
		return b.ServerAddress
	case *nekokfmt.TrojanVLESSBean:
		return b.ServerAddress
	case *nekokfmt.QUICBean:
		return b.ServerAddress
	case *nekokfmt.NaiveBean:
		return b.ServerAddress
	case *nekokfmt.AnyTLSBean:
		return b.ServerAddress
	case *nekokfmt.SSHBean:
		return b.ServerAddress
	case *nekokfmt.WireGuardBean:
		return b.ServerAddress
	case *nekokfmt.CustomBean:
		if b.Core == "internal" {
			var raw map[string]interface{}
			if err := json.Unmarshal([]byte(b.ConfigSimple), &raw); err == nil {
				if s, ok := raw["server"].(string); ok {
					return s
				}
			}
		}
		return b.ServerAddress
	}
	return ""
}

func getCustomOutbound(ent *nekokfmt.ProxyEntity) string {
	// bean is raw json; extract c_out
	var m map[string]interface{}
	if err := json.Unmarshal(ent.Bean, &m); err != nil {
		return ""
	}
	if v, ok := m["c_out"].(string); ok {
		return v
	}
	return ""
}

func isIPAddress(s string) bool {
	if s == "" {
		return false
	}
	host, _, err := net.SplitHostPort(s)
	if err != nil {
		host = s
	}
	host = strings.TrimPrefix(strings.TrimSuffix(host, "]"), "[")
	return net.ParseIP(host) != nil
}

func getRuleSetURL(tag string) string {
	if strings.HasPrefix(tag, "geoip-") {
		return fmt.Sprintf("https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/%s.srs", tag)
	}
	return fmt.Sprintf("https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/%s.srs", tag)
}

// makeRule mirrors the make_rule lambda in ConfigBuilder.cpp.
//
// It converts a list of v2ray-style rule strings (geosite:/geoip:/domain:/...)
// into a sing-box rule object conforming to sing-box 1.13+ rule_set standards.
func makeRule(list []string, isIP bool) map[string]interface{} {
	rule := map[string]interface{}{}
	var ipCidr, domainKeyword, domainSubdomain, domainRegexp, domainFull []interface{}
	var ruleSetTags []string
	var ipIsPrivate bool

	for _, item := range list {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		if isIP {
			if strings.HasPrefix(item, "geoip:") {
				name := strings.TrimPrefix(item, "geoip:")
				if name == "private" {
					ipIsPrivate = true
				} else {
					tag := "geoip-" + name
					ruleSetTags = append(ruleSetTags, tag)
				}
			} else {
				ipCidr = append(ipCidr, item)
			}
		} else {
			switch {
			case strings.HasPrefix(item, "geosite:"):
				name := strings.TrimPrefix(item, "geosite:")
				if name == "private" {
					ipIsPrivate = true
				} else {
					tag := "geosite-" + name
					ruleSetTags = append(ruleSetTags, tag)
				}
			case strings.HasPrefix(item, "full:"):
				domainFull = append(domainFull, strings.ToLower(strings.TrimPrefix(item, "full:")))
			case strings.HasPrefix(item, "domain:"):
				domainSubdomain = append(domainSubdomain, strings.ToLower(strings.TrimPrefix(item, "domain:")))
			case strings.HasPrefix(item, "regexp:"):
				domainRegexp = append(domainRegexp, strings.ToLower(strings.TrimPrefix(item, "regexp:")))
			case strings.HasPrefix(item, "keyword:"):
				domainKeyword = append(domainKeyword, strings.ToLower(strings.TrimPrefix(item, "keyword:")))
			default:
				domainSubdomain = append(domainSubdomain, strings.ToLower(item))
			}
		}
	}
	if isIP {
		if len(ipCidr) == 0 && len(ruleSetTags) == 0 && !ipIsPrivate {
			return nil
		}
		if len(ipCidr) > 0 {
			rule["ip_cidr"] = ipCidr
		}
		if len(ruleSetTags) > 0 {
			rule["rule_set"] = ruleSetTags
		}
		if ipIsPrivate {
			rule["ip_is_private"] = true
		}
	} else {
		if len(domainKeyword) == 0 && len(domainSubdomain) == 0 && len(domainRegexp) == 0 && len(domainFull) == 0 && len(ruleSetTags) == 0 && !ipIsPrivate {
			return nil
		}
		if len(domainFull) > 0 {
			rule["domain"] = domainFull
		}
		if len(domainSubdomain) > 0 {
			rule["domain_suffix"] = domainSubdomain
		}
		if len(domainKeyword) > 0 {
			rule["domain_keyword"] = domainKeyword
		}
		if len(domainRegexp) > 0 {
			rule["domain_regex"] = domainRegexp
		}
		if len(ruleSetTags) > 0 {
			rule["rule_set"] = ruleSetTags
		}
		if ipIsPrivate {
			rule["ip_is_private"] = true
		}
	}
	return rule
}

// buildDNS mirrors the DNS section of BuildConfigSingBox.
func buildDNS(status *BuildStatus, result *BuildResult) {
	routing := status.Routing
	ds := status.DataStore

	var dnsServers []map[string]interface{}
	var dnsRules []map[string]interface{}

	underlyingDNS := ds.CoreBoxUnderlyingDNS
	if underlyingDNS == "" {
		underlyingDNS = "local"
	}

	// Remote
	if !status.ForTest {
		dnsServers = append(dnsServers, map[string]interface{}{
			"tag":              "dns-remote",
			"address_resolver": "dns-local",
			"strategy":         routing.RemoteDNSStrategy,
			"address":          routing.RemoteDNS,
			"detour":           "proxy",
		})
	}

	// Direct
	directObj := map[string]interface{}{
		"tag":              "dns-direct",
		"address_resolver": "dns-local",
		"strategy":         routing.DirectDNSStrategy,
		"address":          routing.DirectDNS,
		"detour":           "direct",
	}
	if routing.DNSFinalOut == "bypass" {
		dnsServers = prependMap(dnsServers, directObj)
	} else {
		dnsServers = append(dnsServers, directObj)
	}
	dnsRules = append(dnsRules, map[string]interface{}{
		"outbound": "any",
		"server":   "dns-direct",
	})

	// block
	if !status.ForTest {
		dnsServers = append(dnsServers, map[string]interface{}{
			"tag":     "dns-block",
			"address": "rcode://success",
		})
	}

	// fakedns
	if ds.FakeDNS && ds.VPNInternalTun && ds.SpmodeVPN && !status.ForTest {
		dnsServers = append(dnsServers, map[string]interface{}{
			"tag":     "dns-fake",
			"address": "fakeip",
		})
	}

	// underlying
	dnsServers = append(dnsServers, map[string]interface{}{
		"tag":     "dns-local",
		"address": underlyingDNS,
		"detour":  "direct",
	})

	// dns rules for domain lists
	addRuleDNS := func(list []string, server string) {
		rule := makeRule(list, false)
		if rule == nil {
			return
		}
		rule["server"] = server
		dnsRules = append(dnsRules, rule)
	}
	addRuleDNS(status.DomainListDNSRemote, "dns-remote")
	addRuleDNS(status.DomainListDNSDirect, "dns-direct")

	// built-in rules
	if !status.ForTest {
		dnsRules = append(dnsRules, map[string]interface{}{
			"query_type": []int{32, 33},
			"server":     "dns-block",
		})
		dnsRules = append(dnsRules, map[string]interface{}{
			"domain_suffix": ".lan",
			"server":        "dns-block",
		})
	}

	// fakedns rule
	if ds.FakeDNS && ds.VPNInternalTun && ds.SpmodeVPN && !status.ForTest {
		dnsRules = append(dnsRules, map[string]interface{}{
			"inbound": "tun-in",
			"server":  "dns-fake",
		})
	}

	dns := map[string]interface{}{
		"servers":           dnsServers,
		"rules":             dnsRules,
		"independent_cache": true,
	}

	if ds.FakeDNS && ds.VPNInternalTun && ds.SpmodeVPN && !status.ForTest {
		dns["fakeip"] = map[string]interface{}{
			"enabled":     true,
			"inet4_range": "198.18.0.0/15",
			"inet6_range": "fc00::/18",
		}
	}

	if routing.UseDNSObject {
		var raw map[string]interface{}
		if err := json.Unmarshal([]byte(routing.DNSObject), &raw); err == nil {
			dns = raw
		}
	}

	result.CoreConfig["dns"] = dns
}

// buildRoute mirrors the Route section of BuildConfigSingBox.
func buildRoute(status *BuildStatus, result *BuildResult, tagProxy string) {
	routing := status.Routing
	ds := status.DataStore

	// dns hijack
	if !status.ForTest {
		status.RoutingRules = append(status.RoutingRules, map[string]interface{}{
			"protocol": "dns",
			"action":   "hijack-dns",
		})
	}

	addRuleRoute := func(list []string, isIP bool, out string) {
		rule := makeRule(list, isIP)
		if rule == nil {
			return
		}
		rule["outbound"] = out
		status.RoutingRules = append(status.RoutingRules, rule)
	}
	addRuleRoute(status.DomainListBlock, false, "block")
	addRuleRoute(status.DomainListRemote, false, tagProxy)
	addRuleRoute(status.DomainListDirect, false, "bypass")
	addRuleRoute(status.IPListBlock, true, "block")
	addRuleRoute(status.IPListRemote, true, tagProxy)
	addRuleRoute(status.IPListDirect, true, "bypass")

	// built-in block rules
	status.RoutingRules = append(status.RoutingRules,
		map[string]interface{}{
			"network":  "udp",
			"port":     []int{135, 137, 138, 139, 5353},
			"outbound": "block",
		},
		map[string]interface{}{
			"ip_cidr":  []string{"224.0.0.0/3", "ff00::/8"},
			"outbound": "block",
		},
		map[string]interface{}{
			"source_ip_cidr": []string{"224.0.0.0/3", "ff00::/8"},
			"outbound":       "block",
		},
	)

	// tun user rules
	if ds.VPNInternalTun && ds.SpmodeVPN && !status.ForTest {
		matchOut := "proxy"
		if ds.VPNRuleWhite {
			matchOut = "bypass"
		}
		if pn := strings.TrimSpace(ds.VPNRuleProcess); pn != "" {
			arr := splitLinesSkipSharp(pn)
			status.RoutingRules = append(status.RoutingRules, map[string]interface{}{
				"outbound":     matchOut,
				"process_name": arr,
			})
		}
		if cidr := strings.TrimSpace(ds.VPNRuleCIDR); cidr != "" {
			arr := splitLinesSkipSharp(cidr)
			status.RoutingRules = append(status.RoutingRules, map[string]interface{}{
				"outbound": matchOut,
				"ip_cidr":  arr,
			})
		}
	}

	// merge custom_route_global rules
	var customGlobalRules []interface{}
	if ds.CustomRouteGlobal != "" {
		var cg map[string]interface{}
		if err := json.Unmarshal([]byte(ds.CustomRouteGlobal), &cg); err == nil {
			if r, ok := cg["rules"].([]interface{}); ok {
				customGlobalRules = r
			}
		}
	}

	// merge custom routing rules
	var customRules []interface{}
	if routing.Custom != "" {
		var cr map[string]interface{}
		if err := json.Unmarshal([]byte(routing.Custom), &cr); err == nil {
			if r, ok := cr["rules"].([]interface{}); ok {
				customRules = r
			}
		}
	}

	allRules := []interface{}{}
	if routing.SniffingMode != nekokfmt.SniffingModeDisable {
		allRules = append(allRules, map[string]interface{}{
			"action": "sniff",
		})
	}
	allRules = append(allRules, customRules...)
	allRules = append(allRules, customGlobalRules...)
	for _, r := range status.RoutingRules {
		allRules = append(allRules, r)
	}

	// Collect all referenced rule_set tags across all rules
	ruleSetMap := make(map[string]bool)
	collectRuleSets := func(rules []interface{}) {
		for _, r := range rules {
			if m, ok := r.(map[string]interface{}); ok {
				if rs, ok := m["rule_set"].([]string); ok {
					for _, tag := range rs {
						ruleSetMap[tag] = true
					}
				} else if rs, ok := m["rule_set"].([]interface{}); ok {
					for _, tag := range rs {
						if s, ok := tag.(string); ok {
							ruleSetMap[s] = true
						}
					}
				}
			}
		}
	}
	collectRuleSets(allRules)
	if dnsObj, ok := result.CoreConfig["dns"].(map[string]interface{}); ok {
		if dnsRules, ok := dnsObj["rules"].([]map[string]interface{}); ok {
			for _, dr := range dnsRules {
				if rs, ok := dr["rule_set"].([]string); ok {
					for _, tag := range rs {
						ruleSetMap[tag] = true
					}
				} else if rs, ok := dr["rule_set"].([]interface{}); ok {
					for _, tag := range rs {
						if s, ok := tag.(string); ok {
							ruleSetMap[s] = true
						}
					}
				}
			}
		}
	}

	var ruleSetList []map[string]interface{}
	for tag := range ruleSetMap {
		ruleSetList = append(ruleSetList, map[string]interface{}{
			"tag":             tag,
			"type":            "remote",
			"format":          "binary",
			"url":             getRuleSetURL(tag),
			"download_detour": "direct",
		})
	}

	routeObj := map[string]interface{}{
		"rules":                 allRules,
		"auto_detect_interface": ds.SpmodeVPN,
	}
	if len(ruleSetList) > 0 {
		routeObj["rule_set"] = ruleSetList
	}
	if routing.DomainStrategy != "" {
		routeObj["default_domain_resolver"] = map[string]interface{}{
			"server":   "dns-direct",
			"strategy": routing.DomainStrategy,
		}
	} else {
		routeObj["default_domain_resolver"] = "dns-direct"
	}
	if !status.ForTest {
		routeObj["final"] = routing.DefOutbound
	}
	if status.ForExport {
		delete(routeObj, "auto_detect_interface")
	}
	result.CoreConfig["route"] = routeObj
}

func prependMap(s []map[string]interface{}, m map[string]interface{}) []map[string]interface{} {
	return append([]map[string]interface{}{m}, s...)
}
