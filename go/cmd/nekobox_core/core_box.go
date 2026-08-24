package main

import (
	"context"
	"io"
	"net"
	"net/http"
	"sync"
	"time"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/metadata"
)

var instanceMu sync.RWMutex
var instance *box.Box
var instanceCtx context.Context
var instanceCancel context.CancelFunc

// CoreVersion is the nekobox_core version (printed on startup).
const CoreVersion = "5.0.0-beta.9"

// Debug toggles verbose logging (set via --debug flag).
var Debug bool

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
	return &http.Client{Transport: transport, Timeout: 30 * time.Second}
}

// createInstance creates a sing-box instance from JSON config and starts it.
func createInstance(configContent []byte) (*box.Box, context.CancelFunc, context.Context, error) {
	boxCtx := include.Context(context.Background())

	var options option.Options
	err := options.UnmarshalJSONContext(boxCtx, configContent)
	if err != nil {
		return nil, nil, nil, err
	}

	ctx, cancel := context.WithCancel(boxCtx)
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

// urlTest measures HTTP latency to a URL through the given Box instance.
// Replaces the libneko speedtest.UrlTest helper with a native implementation.
func urlTest(client *http.Client, target string, timeout int) (int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeout)*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", target, nil)
	if err != nil {
		return 0, err
	}
	start := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	return int(time.Since(start).Milliseconds()), nil
}

// tcpPing measures raw TCP connect latency.
// Replaces the libneko speedtest.TcpPing helper.
func tcpPing(address string, timeout int) (int, error) {
	// Ensure it has a port
	if _, _, err := net.SplitHostPort(address); err != nil {
		address = net.JoinHostPort(address, "443")
	}
	start := time.Now()
	conn, err := net.DialTimeout("tcp", address, time.Duration(timeout)*time.Second)
	if err != nil {
		return 0, err
	}
	conn.Close()
	return int(time.Since(start).Milliseconds()), nil
}

// dialSystem dials a direct connection (not through the proxy).
func dialSystem(ctx context.Context, network, addr string) (net.Conn, error) {
	var d net.Dialer
	return d.DialContext(ctx, network, addr)
}

// createSystemHttpClient creates an http.Client with direct (non-proxy) dialing.
func createSystemHttpClient() *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			DialContext: dialSystem,
		},
		Timeout: 30 * time.Second,
	}
}

// resolveProxyClient returns an HTTP client: through the box if running,
// otherwise a direct system client.
func resolveProxyClient() *http.Client {
	instanceMu.RLock()
	defer instanceMu.RUnlock()
	if instance != nil {
		return newProxyHttpClient(instance)
	}
	return createSystemHttpClient()
}
