package main

import (
	"context"
	"net"
	"net/http"

	"github.com/matsuridayo/libneko/neko_common"
	"github.com/matsuridayo/libneko/neko_log"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/metadata"
)

var instance *box.Box
var instanceCtx context.Context
var instanceCancel context.CancelFunc

// setupCore wires the libneko callbacks to use the running sing-box instance.
//
// On upstream sing-box (>= 1.11), the Box instance exposes Router()/Outbound()
// directly. The legacy MatsuriDayo boxapi helpers are replaced with the
// upstream common/dialer package and the service registry.
func setupCore() {
	neko_log.SetupLog(50*1024, "./neko.log")

	neko_common.GetCurrentInstance = func() interface{} {
		return instance
	}

	neko_common.DialContext = func(ctx context.Context, specifiedInstance interface{}, network, addr string) (net.Conn, error) {
		if b, ok := specifiedInstance.(*box.Box); ok {
			return dialThroughBox(ctx, b, network, addr)
		}
		if instance != nil {
			return dialThroughBox(ctx, instance, network, addr)
		}
		return neko_common.DialContextSystem(ctx, network, addr)
	}

	neko_common.DialUDP = func(ctx context.Context, specifiedInstance interface{}) (net.PacketConn, error) {
		if b, ok := specifiedInstance.(*box.Box); ok {
			return listenPacketThroughBox(ctx, b)
		}
		if instance != nil {
			return listenPacketThroughBox(ctx, instance)
		}
		return neko_common.DialUDPSystem(ctx)
	}

	neko_common.CreateProxyHttpClient = func(specifiedInstance interface{}) *http.Client {
		if b, ok := specifiedInstance.(*box.Box); ok {
			return newProxyHttpClient(b)
		}
		if instance != nil {
			return newProxyHttpClient(instance)
		}
		return neko_common.CreateProxyHttpClient(nil)
	}
}

// dialThroughBox dials a connection through the default outbound of the Box instance.
func dialThroughBox(ctx context.Context, b *box.Box, network, addr string) (net.Conn, error) {
	destination := metadata.ParseSocksaddr(addr)
	return b.Outbound().Default().DialContext(ctx, network, destination)
}

// listenPacketThroughBox listens a packet connection through the default outbound.
func listenPacketThroughBox(ctx context.Context, b *box.Box) (net.PacketConn, error) {
	return b.Outbound().Default().ListenPacket(ctx, metadata.Socksaddr{})
}

// newProxyHttpClient builds an http.Client that routes through the Box instance.
func newProxyHttpClient(b *box.Box) *http.Client {
	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			return dialThroughBox(ctx, b, network, addr)
		},
	}
	return &http.Client{
		Transport: transport,
	}
}

// createInstance creates a sing-box instance from JSON config and starts it.
//
// This replaces the legacy boxmain.Create helper from the MatsuriDayo fork.
// On upstream sing-box, box.New does not call Start automatically, so we do
// it here and return a cancel function along with the instance context.
func createInstance(configContent []byte) (*box.Box, context.CancelFunc, context.Context, error) {
	var options option.Options
	err := options.UnmarshalJSONContext(context.Background(), configContent)
	if err != nil {
		return nil, nil, nil, err
	}

	ctx, cancel := context.WithCancel(context.Background())
	inst, err := box.New(box.Options{
		Context: ctx,
		Options: options,
	})
	if err != nil {
		cancel()
		return nil, nil, nil, err
	}

	err = inst.Start()
	if err != nil {
		cancel()
		inst.Close()
		return nil, nil, nil, err
	}

	return inst, cancel, ctx, nil
}

// (no package-level vars; instance state is declared above)
