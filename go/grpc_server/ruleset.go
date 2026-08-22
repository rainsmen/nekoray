package grpc_server

import (
	"context"
	"sync"

	"grpc_server/gen"
	"grpc_server/core/ruleset"
)

// ruleSetMgr is the process-wide rule_set cache manager.
var (
	ruleSetMgr     *ruleset.Manager
	ruleSetMgrOnce sync.Once
)

func getRuleSetMgr() *ruleset.Manager {
	ruleSetMgrOnce.Do(func() {
		ruleSetMgr = ruleset.NewManager("")
	})
	return ruleSetMgr
}

// UpdateRuleSet registers and optionally downloads a remote rule_set.
func (s *BaseServer) UpdateRuleSet(ctx context.Context, in *gen.UpdateRuleSetReq) (*gen.ErrorResp, error) {
	resp := &gen.ErrorResp{}
	mgr := getRuleSetMgr()

	if in.Download && in.Url != "" {
		_, err := mgr.Download(ctx, in.Tag, in.Format, in.Url)
		if err != nil {
			resp.Error = err.Error()
			return resp, nil
		}
	} else {
		mgr.Register(in.Tag, in.Format, in.Url)
	}
	return resp, nil
}

// ListRuleSets returns info about cached rule_sets.
func (s *BaseServer) ListRuleSets(ctx context.Context, in *gen.EmptyReq) (*gen.ListRuleSetsResp, error) {
	resp := &gen.ListRuleSetsResp{}
	mgr := getRuleSetMgr()
	for _, info := range mgr.List() {
		resp.RuleSets = append(resp.RuleSets, &gen.RuleSetInfo{
			Tag:       info.Tag,
			Type:      info.Type,
			Format:    info.Format,
			Url:       info.URL,
			UpdatedAt: info.UpdatedAt,
			Size:      info.Size,
		})
	}
	return resp, nil
}
