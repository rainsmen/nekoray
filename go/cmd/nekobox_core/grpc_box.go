package main

import (
	"context"
	"errors"
	"fmt"
	"log"

	"grpc_server"
	"grpc_server/gen"

	"github.com/matsuridayo/libneko/neko_common"
	"github.com/matsuridayo/libneko/speedtest"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/experimental/v2rayapi"
	"github.com/sagernet/sing/service"

	_ "unsafe" // for go:linkname version injection if needed
)

type server struct {
	grpc_server.BaseServer
}

// Start loads the sing-box config and starts a new instance.
func (s *server) Start(ctx context.Context, in *gen.LoadConfigReq) (out *gen.ErrorResp, _ error) {
	var err error

	defer func() {
		out = &gen.ErrorResp{}
		if err != nil {
			out.Error = err.Error()
			instance = nil
		}
	}()

	if neko_common.Debug {
		log.Println("Start:", in.CoreConfig)
	}

	if instance != nil {
		err = errors.New("instance already started")
		return
	}

	instance, instanceCancel, instanceCtx, err = createInstance([]byte(in.CoreConfig))
	if err != nil {
		return
	}

	// NOTE: upstream sing-box logs via its own log factory configured in the
	// "log" field of the JSON config. The legacy MatsuriDayo fork exposed a
	// SetLogWritter helper to bridge logs into neko_log.LogWriter; upstream
	// does not, so log routing is controlled by the config's log section.

	return
}

// Stop stops the running instance.
func (s *server) Stop(ctx context.Context, in *gen.EmptyReq) (out *gen.ErrorResp, _ error) {
	var err error

	defer func() {
		out = &gen.ErrorResp{}
		if err != nil {
			out.Error = err.Error()
		}
	}()

	if instance == nil {
		return
	}

	instanceCancel()
	instance.Close()

	instance = nil
	instanceCancel = nil

	return
}

// Test performs latency / speed / full tests.
func (s *server) Test(ctx context.Context, in *gen.TestReq) (out *gen.TestResp, _ error) {
	var err error
	out = &gen.TestResp{Ms: 0}

	defer func() {
		if err != nil {
			out.Error = err.Error()
		}
	}()

	if in.Mode == gen.TestMode_UrlTest {
		var i *box.Box
		var cancel context.CancelFunc
		if in.Config != nil {
			// Test instance
			i, cancel, _, err = createInstance([]byte(in.Config.CoreConfig))
			if i != nil {
				defer i.Close()
				defer cancel()
			}
			if err != nil {
				return
			}
		} else {
			// Test running instance
			i = instance
			if i == nil {
				return
			}
		}
		// Latency
		out.Ms, err = speedtest.UrlTest(newProxyHttpClient(i), in.Url, in.Timeout, speedtest.UrlTestStandard_RTT)
	} else if in.Mode == gen.TestMode_TcpPing {
		out.Ms, err = speedtest.TcpPing(in.Address, in.Timeout)
	} else if in.Mode == gen.TestMode_FullTest {
		i, cancel, _, err := createInstance([]byte(in.Config.CoreConfig))
		if i != nil {
			defer i.Close()
			defer cancel()
		}
		if err != nil {
			return
		}
		return grpc_server.DoFullTest(ctx, in, i)
	}

	return
}

// QueryStats returns the traffic counter for the given outbound tag.
//
// On upstream sing-box, the V2RayServer's StatsService is obtained from the
// service registry. Its GetStats method returns the counter value for a name
// of the form "outbound>>>tag>>>traffic>>>direct|uplink|downlink".
func (s *server) QueryStats(ctx context.Context, in *gen.QueryStatsReq) (out *gen.QueryStatsResp, _ error) {
	out = &gen.QueryStatsResp{}

	if instance != nil && instanceCtx != nil {
		v2rayServer := service.FromContext[adapter.V2RayServer](instanceCtx)
		if v2rayServer != nil {
			tracker := v2rayServer.StatsService()
			if tracker != nil {
				// The concrete *v2rayapi.StatsService exposes GetStats,
				// which is not on the ConnectionTracker interface.
				type statsQueryer interface {
					GetStats(ctx context.Context, request *v2rayapi.GetStatsRequest) (*v2rayapi.GetStatsResponse, error)
				}
				if q, ok := tracker.(statsQueryer); ok {
					name := fmt.Sprintf("outbound>>>%s>>>traffic>>>%s", in.Tag, in.Direct)
					resp, err := q.GetStats(ctx, &v2rayapi.GetStatsRequest{Name: name})
					if err == nil && resp != nil && resp.Stat != nil {
						out.Traffic = resp.Stat.Value
					}
				}
			}
		}
	}

	return
}

// ListConnections lists active connections.
// ListConnections lists active connections.
//
// Phase-1: returns empty. Full connection tracking requires either the
// Clash API (/connections, needs experimental.clash_api enabled in config) or
// the V2Ray API connection tracker. This is implemented in phase 2 together
// with the Flutter connection-management UI.
func (s *server) ListConnections(ctx context.Context, in *gen.EmptyReq) (*gen.ListConnectionsResp, error) {
	out := &gen.ListConnectionsResp{}
	return out, nil
}
