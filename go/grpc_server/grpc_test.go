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

// TestRunCoreBoundRestart proves the Android lifecycle: bind (nil means the
// port is connectable), stop cleanly, and bind again. Port 0 lets the OS
// pick, avoiding collisions on shared CI runners.
func TestRunCoreBoundRestart(t *testing.T) {
	const token = "0123456789abcdef0123456789abcdef"
	for i := 0; i < 2; i++ {
		if err := RunCoreBound(token, 0, false, &BaseServer{}); err != nil {
			t.Fatalf("cycle %d: RunCoreBound: %v", i, err)
		}
		StopServer()
	}
	// Stopping an idle server must not panic or hang.
	StopServer()
}
