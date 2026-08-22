// Package fmt defines the NekoGui proxy bean data models.
//
// These mirror the C++ classes in fmt/*.hpp so that profile JSON written by
// the old client can be read directly, and config generation can run inside
// nekobox_core (phase 1 migration: ConfigBuilder sink-down).
package fmt

// BeanType identifies a proxy protocol.
type BeanType string

const (
	BeanSocks        BeanType = "socks"
	BeanHTTP         BeanType = "http"
	BeanShadowsocks  BeanType = "shadowsocks"
	BeanVMess        BeanType = "vmess"
	BeanVLESS        BeanType = "vless"
	BeanTrojan       BeanType = "trojan"
	BeanHysteria2    BeanType = "hysteria2"
	BeanTUIC         BeanType = "tuic"
	BeanNaive        BeanType = "naive"
	BeanCustom       BeanType = "custom"
	BeanChain        BeanType = "chain"
	BeanSSH         BeanType = "ssh"        // phase 1 new
	BeanWireGuard   BeanType = "wireguard" // phase 1 new
	BeanAnyTLS      BeanType = "anytls"     // phase 1 new
)

// AbstractBean mirrors NekoGui_fmt::AbstractBean.
//
// JSON tags match the C++ configItem names so that profile JSON is compatible.
type AbstractBean struct {
	Version       int    `json:"_v"`
	Name          string `json:"name"`
	ServerAddress string `json:"addr"`
	ServerPort    int    `json:"port"`
	CustomConfig  string `json:"c_cfg"`
	CustomOutbound string `json:"c_out"`
}

// V2RayStreamSettings mirrors NekoGui_fmt::V2rayStreamSettings.
type V2RayStreamSettings struct {
	Network          string `json:"net"`
	Security         string `json:"sec"`
	PacketEncoding   string `json:"pac_enc"`
	Path             string `json:"path"`
	Host             string `json:"host"`
	HeaderType       string `json:"h_type"`
	Sni              string `json:"sni"`
	Alpn             string `json:"alpn"`
	Certificate      string `json:"cert"`
	AllowInsecure    bool   `json:"insecure"`
	WsEarlyDataName  string `json:"ed_name"`
	WsEarlyDataLen   int    `json:"ed_len"`
	UtlsFingerprint  string `json:"utls"`
	RealityPbk       string `json:"pbk"`
	RealitySid       string `json:"sid"`
	RealitySpx       string `json:"spx"`
	MultiplexStatus  int    `json:"mux_s"`
}

// VMessBean mirrors NekoGui_fmt::VMessBean.
type VMessBean struct {
	AbstractBean
	Uuid     string                `json:"id"`
	Aid      int                   `json:"aid"`
	Security string                `json:"sec"`
	Stream   *V2RayStreamSettings  `json:"stream"`
}

// TrojanVLESSBean mirrors NekoGui_fmt::TrojanVLESSBean (trojan & vless).
type TrojanVLESSBean struct {
	AbstractBean
	Password string                `json:"password"`
	Flow     string                `json:"flow"`
	ProxyType int                  `json:"proxy_type"` // 0 trojan, 1 vless
	Stream   *V2RayStreamSettings  `json:"stream"`
}

const (
	TrojanVLESSProxyTrojan = 0
	TrojanVLESSProxyVLESS  = 1
)

// ShadowSocksBean mirrors NekoGui_fmt::ShadowSocksBean.
type ShadowSocksBean struct {
	AbstractBean
	Method   string `json:"method"`
	Password string `json:"password"`
	Plugin   string `json:"plugin"`
	Uot      int    `json:"uot"`
	Stream   *V2RayStreamSettings `json:"stream"`
}

// SocksHttpBean mirrors NekoGui_fmt::SocksHttpBean.
type SocksHttpBean struct {
	AbstractBean
	SocksHttpType int    `json:"socks_http_type"`
	Username      string `json:"username"`
	Password      string `json:"password"`
	Stream        *V2RayStreamSettings `json:"stream"`
}

const (
	SocksHttpTypeSocks4  = 0
	SocksHttpTypeSocks   = 1
	SocksHttpTypeHTTP    = 2
)

// QUICBean mirrors NekoGui_fmt::QUICBean (hysteria2 & tuic).
type QUICBean struct {
	AbstractBean
	ProxyType             int    `json:"proxy_type"`
	ForceExternal         bool   `json:"forceExternal"`

	// Hysteria2
	ObfsPassword          string `json:"obfsPassword"`
	UploadMbps            int    `json:"uploadMbps"`
	DownloadMbps          int    `json:"downloadMbps"`
	StreamReceiveWindow   int64  `json:"streamReceiveWindow"`
	ConnectionReceiveWindow int64 `json:"connectionReceiveWindow"`
	DisableMtuDiscovery   bool   `json:"disableMtuDiscovery"`
	HopInterval           int    `json:"hopInterval"`
	HopPort               string `json:"hopPort"`
	Password              string `json:"password"`

	// TUIC
	Uuid                  string `json:"uuid"`
	CongestionControl     string `json:"congestionControl"`
	UdpRelayMode          string `json:"udpRelayMode"`
	ZeroRttHandshake      bool   `json:"zeroRttHandshake"`
	Heartbeat             string `json:"heartbeat"`
	Uos                   bool   `json:"uos"`

	// TLS
	AllowInsecure         bool   `json:"allowInsecure"`
	Sni                   string `json:"sni"`
	Alpn                  string `json:"alpn"`
	CaText                string `json:"caText"`
	DisableSni            bool   `json:"disableSni"`
}

const (
	QUICProxyHysteria2 = 3
	QUICProxyTUIC      = 1
)

// CustomBean mirrors NekoGui_fmt::CustomBean.
type CustomBean struct {
	AbstractBean
	Core        string `json:"core"`
	ConfigSimple string `json:"config_simple"`
	MappingPort int    `json:"mapping_port"`
	SocksPort   int    `json:"socks_port"`
}

// ChainBean mirrors NekoGui_fmt::ChainBean.
type ChainBean struct {
	AbstractBean
	List []int `json:"list"`
}
