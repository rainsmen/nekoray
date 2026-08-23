package main

import (
	"context"
	"errors"
	"fmt"
	"log"

	"grpc_server"
	"grpc_server/gen"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/experimental/v2rayapi"
	"github.com/sagernet/sing/service"
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

	if Debug {
		log.Println("Start:", in.CoreConfig)
	}

	if instance != nil {
		err = errors.New("instance already started")
		return
	}

	instance, instanceCancel, instanceCtx, err = createInstance([]byte(in.CoreConfig))
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
			i, cancel, _, err = createInstance([]byte(in.Config.CoreConfig))
			if i != nil {
				defer i.Close()
				defer cancel()
			}
			if err != nil {
				return
			}
		} else {
			i = instance
			if i == nil {
				return
			}
		}
		// Native URL test (replaces libneko speedtest.UrlTest)
		var ms int
		ms, err = urlTest(newProxyHttpClient(i), in.Url, int(in.Timeout))
		out.Ms = int32(ms)
	} else if in.Mode == gen.TestMode_TcpPing {
		// Native TCP ping (replaces libneko speedtest.TcpPing)
		var ms int
		ms, err = tcpPing(in.Address, int(in.Timeout))
		out.Ms = int32(ms)
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

	if instance != nil && instanceCtx != nil {
		v2rayServer := service.FromContext[adapter.V2RayServer](instanceCtx)
		if v2rayServer != nil {
			tracker := v2rayServer.StatsService()
			if tracker != nil {
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
//
// Phase-1: returns empty. Full connection tracking requires the Clash API
// (/connections), to be implemented in phase 2 with the Flutter UI.
func (s *server) ListConnections(ctx context.Context, in *gen.EmptyReq) (*gen.ListConnectionsResp, error) {
	return &gen.ListConnectionsResp{}, nil
}
