package fmt

import "encoding/json"

// ProxyEntity mirrors NekoGui::ProxyEntity.
//
// Bean is stored as a raw JSON message so that it can be decoded into the
// concrete bean type based on Type.
type ProxyEntity struct {
	Type           string          `json:"type"`
	Id             int             `json:"id"`
	Gid            int             `json:"gid"`
	Latency        int             `json:"latency"`
	Bean           json.RawMessage `json:"bean"`
	FullTestReport string          `json:"full_test_report"`

	// runtime-only
	// TrafficData omitted (UI concern)
}

// Group mirrors NekoGui::Group.
type Group struct {
	Id                  int    `json:"id"`
	Archive             bool   `json:"archive"`
	SkipAutoUpdate      bool   `json:"skip_auto_update"`
	Name                string `json:"name"`
	Url                 string `json:"url"`
	Info                string `json:"info"`
	SubLastUpdate       int64  `json:"sub_last_update"`
	FrontProxyId        int    `json:"front_proxy_id"`
	ManuallyColumnWidth bool   `json:"manually_column_width"`
	ColumnWidth         []int  `json:"column_width"`
	Order               []int  `json:"order"`
}

// Routing mirrors NekoGui::Routing.
type Routing struct {
	DirectDomain string `json:"direct_domain"`
	ProxyDomain  string `json:"proxy_domain"`
	BlockDomain  string `json:"block_domain"`
	DirectIP     string `json:"direct_ip"`
	ProxyIP      string `json:"proxy_ip"`
	BlockIP      string `json:"block_ip"`
	DefOutbound  string `json:"def_outbound"`
	Custom       string `json:"custom"`

	// DNS
	RemoteDNS         string `json:"remote_dns"`
	RemoteDNSStrategy string `json:"remote_dns_strategy"`
	DirectDNS         string `json:"direct_dns"`
	DirectDNSStrategy string `json:"direct_dns_strategy"`
	DNSRouting        bool   `json:"dns_routing"`
	UseDNSObject      bool   `json:"use_dns_object"`
	DNSObject         string `json:"dns_object"`
	DNSFinalOut       string `json:"dns_final_out"`

	// Misc
	DomainStrategy         string `json:"domain_strategy"`
	OutboundDomainStrategy string `json:"outbound_domain_strategy"`
	SniffingMode           int    `json:"sniffing_mode"`
}

// SniffingMode constants mirror the C++ SniffingMode enum.
const (
	SniffingModeDisable        = 0
	SniffingModeForRouting     = 1
	SniffingModeForDestination = 2
)

// DataStore mirrors NekoGui::DataStore (subset relevant to config building).
type DataStore struct {
	// Running
	SpmodeVPN         bool `json:"spmode_vpn"`
	SpmodeSystemProxy bool `json:"spmode_system_proxy"`

	// Inbound
	InboundAddress      string `json:"inbound_address"`
	InboundSocksPort    int    `json:"inbound_socks_port"`
	InboundAuthUsername string `json:"inbound_auth_username"`
	InboundAuthPassword string `json:"inbound_auth_password"`

	// Misc
	LogLevel             string `json:"log_level"`
	MuxProtocol          string `json:"mux_protocol"`
	MuxPadding           bool   `json:"mux_padding"`
	MuxConcurrency       int    `json:"mux_concurrency"`
	MuxDefaultOn         bool   `json:"mux_default_on"`
	SkipCert             bool   `json:"skip_cert"`
	UtlsFingerprint      string `json:"utlsFingerprint"`
	CoreBoxUnderlyingDNS string `json:"core_box_underlying_dns"`

	// Routing
	CustomRouteGlobal string `json:"custom_route_global"`
	ActiveRouting     string `json:"active_routing"`

	// VPN
	FakeDNS           bool   `json:"fake_dns"`
	VPNInternalTun    bool   `json:"vpn_internal_tun"`
	VPNImplementation int    `json:"vpn_implementation"`
	VPNMTU            int    `json:"vpn_mtu"`
	VPNIPv6           bool   `json:"vpn_ipv6"`
	VPNStrictRoute    bool   `json:"vpn_strict_route"`
	VPNRuleWhite      bool   `json:"vpn_rule_white"`
	VPNRuleProcess    string `json:"vpn_rule_process"`
	VPNRuleCIDR       string `json:"vpn_rule_cidr"`

	// Custom inbound
	CustomInbound string `json:"custom_inbound"`

	// Core
	CoreBoxClashAPI       int    `json:"core_box_clash_api"`
	CoreBoxClashAPISecret string `json:"core_box_clash_api_secret"`

	// Misc runtime
	IgnoreConnTag []string `json:"ignoreConnTag"`
}

// DecodeBean decodes the raw bean JSON into the appropriate concrete bean type
// based on the entity Type.
func (p *ProxyEntity) DecodeBean() (interface{}, error) {
	switch p.Type {
	case string(BeanSocks), string(BeanHTTP):
		var b SocksHttpBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanShadowsocks):
		var b ShadowSocksBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanVMess):
		var b VMessBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanVLESS), string(BeanTrojan):
		var b TrojanVLESSBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanHysteria2), string(BeanTUIC):
		var b QUICBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanCustom):
		var b CustomBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanChain):
		var b ChainBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanNaive):
		var b NaiveBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanAnyTLS):
		var b AnyTLSBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanSSH):
		var b SSHBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	case string(BeanWireGuard):
		var b WireGuardBean
		err := json.Unmarshal(p.Bean, &b)
		return &b, err
	default:
		return nil, &UnknownBeanTypeError{Type: p.Type}
	}
}

// UnknownBeanTypeError is returned when a profile has an unrecognized type.
type UnknownBeanTypeError struct {
	Type string
}

func (e *UnknownBeanTypeError) Error() string {
	return "unknown bean type: " + e.Type
}

var _ error = (*UnknownBeanTypeError)(nil)
