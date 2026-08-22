package main

import (
	"context"
	"errors"
	"log"

	"grpc_server"
	"grpc_server/gen"

	"github.com/matsuridayo/libneko/neko_common"
	"github.com/matsuridayo/libneko/speedtest"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"
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
func (s *server) QueryStats(ctx context.Context, in *gen.QueryStatsReq) (out *gen.QueryStatsResp, _ error) {
	out = &gen.QueryStatsResp{}

	if instance != nil {
		// On upstream sing-box, V2RayServer is registered via the service
		// registry. Stats are queried through its StatsService().
		v2rayServer := service.FromContext[adapter.V2RayServer](instanceCtx)
		if v2rayServer != nil {
			tracker := v2rayServer.StatsService()
			if tracker != nil {
				// RoutedConnection/RoutedPacketConnection track stats when the
				// outbound has stats enabled. The legacy neko boxapi exposed a
				// QueryStats(name) helper; upstream uses ConnectionTracker
				// interface which does not expose a direct query, so we keep
				// the gRPC field but return 0 for now until the connection
				// tracker API is extended (see DECISIONS.md).
				_ = tracker
				_ = in
			}
		}
	}

	return
}

// ListConnections lists active connections.
//
// TODO: implement via the upstream Clash API (/connections) or V2Ray API.
func (s *server) ListConnections(ctx context.Context, in *gen.EmptyReq) (*gen.ListConnectionsResp, error) {
	out := &gen.ListConnectionsResp{
		// TODO upstream api
	}
	return out, nil
}
