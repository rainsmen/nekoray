package grpc_server

import (
	"bufio"
	"context"
	"fmt"
	"grpc_server/auth"
	"grpc_server/gen"
	"log"
	"net"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	grpc_auth "github.com/grpc-ecosystem/go-grpc-middleware/auth"
	"google.golang.org/grpc"
)

// Debug toggles verbose logging (set via --debug flag).
var Debug bool

// TokenEnvVar is the preferred channel for handing the auth token to the core.
// Passing it as a command-line flag exposes it to every process that can read
// the process table; the environment of a process is readable only by its owner.
const TokenEnvVar = "NEKORAY_AUTH_TOKEN"

type BaseServer struct {
	gen.LibcoreServiceServer
}

// shutdown is installed by RunCore so Exit can stop the server gracefully
// instead of calling os.Exit from inside a request handler. The optional
// cleanup hook lets the embedding application release resources (for example,
// a running sing-box instance) before the process exits.
var shutdown struct {
	sync.Mutex
	fn        func()
	cleanup   func()
	requested bool
}

// SetShutdownHook registers a process-resource cleanup callback for Exit. The
// callback is invoked at most once, after the gRPC server has stopped. It is
// intentionally separate from RunCore's server callback so embedders can wire
// their instance lifecycle without exposing the grpc.Server itself.
func SetShutdownHook(fn func()) {
	shutdown.Lock()
	shutdown.cleanup = fn
	shutdown.Unlock()
}

func (s *BaseServer) Exit(ctx context.Context, in *gen.EmptyReq) (*gen.EmptyResp, error) {
	shutdown.Lock()
	fn := shutdown.fn
	cleanup := shutdown.cleanup
	// Multiple callers may race to exit. Only the first one may schedule the
	// callbacks, otherwise cleanup can run concurrently or twice.
	if fn != nil || cleanup != nil {
		if shutdown.requested {
			fn = nil
			cleanup = nil
		} else {
			shutdown.requested = true
		}
	}
	shutdown.Unlock()

	// Return the response first, then tear down, so the caller is not left
	// with a broken connection instead of an acknowledgement. GracefulStop is
	// called before the application hook so in-flight RPCs can finish while
	// their resources are still available.
	if fn != nil || cleanup != nil {
		go func() {
			time.Sleep(100 * time.Millisecond)
			if fn != nil {
				fn()
			}
			if cleanup != nil {
				cleanup()
			}
		}()
	}
	return &gen.EmptyResp{}, nil
}

// resolveToken obtains the auth token, preferring the environment over an
// interactive prompt. The token is removed from the environment once read so
// it is not inherited by anything the core spawns.
func resolveToken(flagToken string) string {
	if t := strings.TrimSpace(os.Getenv(TokenEnvVar)); t != "" {
		os.Unsetenv(TokenEnvVar)
		return t
	}
	if t := strings.TrimSpace(flagToken); t != "" {
		return t
	}
	os.Stderr.WriteString("Please set a token: ")
	s := bufio.NewScanner(os.Stdin)
	if s.Scan() {
		return strings.TrimSpace(s.Text())
	}
	return ""
}

// watchParent terminates the core when the process that launched it goes away,
// so a crashed GUI cannot leave an orphaned proxy running.
func watchParent() {
	if setupParentDeathSignal() {
		// The kernel will signal us; only handle the race where the parent
		// died between fork and prctl.
		if os.Getppid() == 1 {
			log.Fatalln("parent exited")
		}
		select {}
	}

	// Fallback: poll. Note that Wait() only works for real children, which the
	// parent is not — hence polling on every platform without PDEATHSIG.
	startPPID := os.Getppid()
	for {
		time.Sleep(2 * time.Second)
		if os.Getppid() != startPPID {
			// Re-parented to init: the original parent is gone.
			log.Fatalln("parent exited (reparented)")
		}
		if runtime.GOOS != "windows" {
			parent, err := os.FindProcess(startPPID)
			if err != nil {
				log.Fatalln("parent exited:", err)
			}
			if err := parent.Signal(syscall.Signal(0)); err != nil {
				log.Fatalln("parent exited:", err)
			}
		}
	}
}

// RunCore starts the gRPC server and blocks until it stops.
func RunCore(token string, port int, debug bool, server gen.LibcoreServiceServer) {
	lis, s, err := bindCore(token, port, debug, server)
	if err != nil {
		if _, ok := err.(*bindError); ok {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		log.Fatalf("failed to listen: %v", err)
	}

	// Report the actual port so a caller that passed 0 can discover it.
	fmt.Printf("nekobox_core listening on %v\n", lis.Addr())
	log.Printf("nekobox_core grpc server listening at %v\n", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}

// RunCoreBound starts the gRPC server like RunCore, but returns once the
// listener is bound (the server keeps running) instead of blocking. It
// exists for the Android in-process core, which has no stdout for the
// desktop "listening on" handshake — a nil return means the port is
// connectable right away.
func RunCoreBound(token string, port int, debug bool, server gen.LibcoreServiceServer) error {
	lis, s, err := bindCore(token, port, debug, server)
	if err != nil {
		return err
	}
	log.Printf("nekobox_core grpc server listening at %v\n", lis.Addr())
	go func() {
		if err := s.Serve(lis); err != nil {
			log.Printf("grpc server stopped: %v", err)
		}
	}()
	return nil
}

// StopServer gracefully stops a server started by RunCore/RunCoreBound and
// releases its box instance, so the core can be started again in-process.
// No-op when nothing is running.
func StopServer() {
	shutdown.Lock()
	fn := shutdown.fn
	cleanup := shutdown.cleanup
	shutdown.fn = nil
	shutdown.cleanup = nil
	shutdown.requested = false
	shutdown.Unlock()

	if cleanup != nil {
		cleanup()
	}
	if fn == nil {
		return
	}
	done := make(chan struct{})
	go func() {
		fn()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
	}
}

// bindError marks fatal configuration errors (as opposed to listen/serve
// failures) so callers can reproduce RunCore's exit paths.
type bindError struct{ msg string }

func (e *bindError) Error() string { return e.msg }

// bindCore performs everything RunCore does up to accepting connections and
// hands back the bound listener and server.
func bindCore(token string, port int, debug bool, server gen.LibcoreServiceServer) (net.Listener, *grpc.Server, error) {
	Debug = debug

	go watchParent()

	token = resolveToken(token)
	if token == "" {
		return nil, nil, &bindError{"You must set a token"}
	}
	if len(token) < 16 {
		return nil, nil, &bindError{"Token must be at least 16 characters"}
	}

	lis, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(port))
	if err != nil {
		return nil, nil, err
	}
	os.Stderr.WriteString("token is set\n")

	auther := auth.Authenticator{Token: token}

	s := grpc.NewServer(
		grpc.StreamInterceptor(grpc_auth.StreamServerInterceptor(auther.Authenticate)),
		grpc.UnaryInterceptor(grpc_auth.UnaryServerInterceptor(auther.Authenticate)),
	)
	gen.RegisterLibcoreServiceServer(s, server)

	shutdown.Lock()
	shutdown.fn = s.GracefulStop
	shutdown.requested = false
	shutdown.Unlock()

	return lis, s, nil
}
