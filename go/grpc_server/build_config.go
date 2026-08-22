package grpc_server

import (
	"context"
	"encoding/json"

	"grpc_server/gen"

	"grpc_server/core/config"
	nekokfmt "grpc_server/core/fmt"
)

// BuildConfig implements the gRPC BuildConfig method.
//
// It deserializes the incoming profile/group/routing/datastore JSON, builds
// the full sing-box config, and returns it.
func (s *BaseServer) BuildConfig(ctx context.Context, in *gen.BuildConfigReq) (*gen.BuildConfigResp, error) {
	resp := &gen.BuildConfigResp{}

	var ent nekokfmt.ProxyEntity
	if err := json.Unmarshal(in.ProfileJson, &ent); err != nil {
		resp.Error = "invalid profile_json: " + err.Error()
		return resp, nil
	}

	var group nekokfmt.Group
	if len(in.GroupJson) > 0 {
		if err := json.Unmarshal(in.GroupJson, &group); err != nil {
			resp.Error = "invalid group_json: " + err.Error()
			return resp, nil
		}
	}

	var routing nekokfmt.Routing
	if len(in.RoutingJson) > 0 {
		if err := json.Unmarshal(in.RoutingJson, &routing); err != nil {
			resp.Error = "invalid routing_json: " + err.Error()
			return resp, nil
		}
	}

	var ds nekokfmt.DataStore
	if len(in.DatastoreJson) > 0 {
		if err := json.Unmarshal(in.DatastoreJson, &ds); err != nil {
			resp.Error = "invalid datastore_json: " + err.Error()
			return resp, nil
		}
	}

	result := config.BuildConfig(&ent, &group, &routing, &ds, in.ForTest, in.ForExport)
	if result.Error != "" {
		resp.Error = result.Error
		return resp, nil
	}

	configBytes, err := json.Marshal(result.CoreConfig)
	if err != nil {
		resp.Error = "marshal config: " + err.Error()
		return resp, nil
	}
	resp.CoreConfig = string(configBytes)

	// ext results (JSON encoded list)
	if len(result.ExtResults) > 0 {
		extBytes, _ := json.Marshal(result.ExtResults)
		resp.ExtResults = extBytes
	}

	return resp, nil
}

// ParseSubscription implements the gRPC ParseSubscription method.
//
// Phase-1 MVP: returns empty profile list. Full subscription parsing (raw/clash/
// sip008) is implemented in a later task.
func (s *BaseServer) ParseSubscription(ctx context.Context, in *gen.ParseSubReq) (*gen.ParseSubResp, error) {
	resp := &gen.ParseSubResp{}
	// TODO phase-1 task 3: implement subscription parsing
	return resp, nil
}

// GenerateShareLink implements the gRPC GenerateShareLink method.
//
// Phase-1 MVP: returns empty link. Full link generation is implemented in a
// later task.
func (s *BaseServer) GenerateShareLink(ctx context.Context, in *gen.ShareLinkReq) (*gen.ShareLinkResp, error) {
	resp := &gen.ShareLinkResp{}
	// TODO phase-1 task 3: implement link generation
	return resp, nil
}
