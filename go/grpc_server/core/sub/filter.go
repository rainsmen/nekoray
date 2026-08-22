package sub

import (
	"encoding/json"

	nekokfmt "grpc_server/core/fmt"
)

// ProfileFilter mirrors NekoGui::ProfileFilter.
//
// Provides uniqueness / diff operations on profile lists.
type ProfileFilter struct{}

// Uniq removes duplicate profiles. If keepLast, the later duplicate wins.
// byAddress: compare by (address+type) instead of full bean json.
func (ProfileFilter) Uniq(in []*nekokfmt.ProxyEntity, byAddress, keepLast bool) []*nekokfmt.ProxyEntity {
	var out []*nekokfmt.ProxyEntity
	hashMap := map[string]int{} // key -> index in out

	for _, ent := range in {
		key := profileKey(ent, byAddress)
		if idx, exists := hashMap[key]; exists {
			if keepLast {
				out[idx] = ent
			}
		} else {
			hashMap[key] = len(out)
			out = append(out, ent)
		}
	}
	return out
}

// Common returns profiles present in both lists (by key).
func (ProfileFilter) Common(src, dst []*nekokfmt.ProxyEntity, byAddress bool) (outSrc, outDst []*nekokfmt.ProxyEntity) {
	srcMap := map[string]*nekokfmt.ProxyEntity{}
	for _, ent := range src {
		srcMap[profileKey(ent, byAddress)] = ent
	}
	for _, ent := range dst {
		key := profileKey(ent, byAddress)
		if s, ok := srcMap[key]; ok {
			outSrc = append(outSrc, s)
			outDst = append(outDst, ent)
		}
	}
	return
}

// OnlyInSrc returns profiles in src but not in dst.
func (ProfileFilter) OnlyInSrc(src, dst []*nekokfmt.ProxyEntity, byAddress bool) []*nekokfmt.ProxyEntity {
	var out []*nekokfmt.ProxyEntity
	dstMap := map[string]bool{}
	for _, ent := range dst {
		dstMap[profileKey(ent, byAddress)] = true
	}
	for _, ent := range src {
		if !dstMap[profileKey(ent, byAddress)] {
			out = append(out, ent)
		}
	}
	return out
}

// profileKey mirrors ProfileFilter_ent_key.
//
// byAddress: address + type
// otherwise: bean json (excluding c_cfg, c_out) + type
func profileKey(ent *nekokfmt.ProxyEntity, byAddress bool) string {
	if byAddress && ent.Type != "custom" {
		return displayAddress(ent) + "|" + ent.Type
	}
	// bean json without c_cfg, c_out
	var raw map[string]interface{}
	if err := json.Unmarshal(ent.Bean, &raw); err == nil {
		delete(raw, "c_cfg")
		delete(raw, "c_out")
		if b, err := json.Marshal(raw); err == nil {
			return string(b) + "|" + ent.Type
		}
	}
	return ent.Type
}

// displayAddress extracts server:port from the bean.
func displayAddress(ent *nekokfmt.ProxyEntity) string {
	bean, err := ent.DecodeBean()
	if err != nil {
		return ""
	}
	type addrer interface {
		getAddr() string
		getPort() int
	}
	_ = addrer(nil) // interface guard
	switch b := bean.(type) {
	case *nekokfmt.SocksHttpBean:
		return b.ServerAddress + ":" + itoa(b.ServerPort)
	case *nekokfmt.ShadowSocksBean:
		return b.ServerAddress + ":" + itoa(b.ServerPort)
	case *nekokfmt.VMessBean:
		return b.ServerAddress + ":" + itoa(b.ServerPort)
	case *nekokfmt.TrojanVLESSBean:
		return b.ServerAddress + ":" + itoa(b.ServerPort)
	case *nekokfmt.QUICBean:
		if b.HopPort != "" {
			return b.ServerAddress + ":" + b.HopPort
		}
		return b.ServerAddress + ":" + itoa(b.ServerPort)
	case *nekokfmt.CustomBean:
		return b.ServerAddress + ":" + itoa(b.ServerPort)
	}
	return ""
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
