package grpc_server

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

func TestExitRunsShutdownHookOnce(t *testing.T) {
	shutdown.Lock()
	oldFn, oldCleanup, oldRequested := shutdown.fn, shutdown.cleanup, shutdown.requested
	shutdown.fn, shutdown.cleanup, shutdown.requested = nil, nil, false
	shutdown.Unlock()
	defer func() {
		shutdown.Lock()
		shutdown.fn, shutdown.cleanup, shutdown.requested = oldFn, oldCleanup, oldRequested
		shutdown.Unlock()
	}()

	var calls atomic.Int32
	SetShutdownHook(func() { calls.Add(1) })
	server := &BaseServer{}
	if _, err := server.Exit(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	if _, err := server.Exit(context.Background(), nil); err != nil {
		t.Fatal(err)
	}

	deadline := time.Now().Add(2 * time.Second)
	for calls.Load() != 1 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("shutdown hook called %d times, want once", got)
	}
}
