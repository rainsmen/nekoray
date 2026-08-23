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
// instead of calling os.Exit from inside a request handler.
var shutdown struct {
	sync.Mutex
	fn func()
}

func (s *BaseServer) Exit(ctx context.Context, in *gen.EmptyReq) (*gen.EmptyResp, error) {
	shutdown.Lock()
	fn := shutdown.fn
	shutdown.Unlock()

	// Return the response first, then tear down, so the caller is not left
	// with a broken connection instead of an acknowledgement.
	if fn != nil {
		go func() {
			time.Sleep(100 * time.Millisecond)
			fn()
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
	Debug = debug

	go watchParent()

	token = resolveToken(token)
	if token == "" {
		fmt.Fprintln(os.Stderr, "You must set a token")
		os.Exit(1)
	}
	if len(token) < 16 {
		fmt.Fprintln(os.Stderr, "Token must be at least 16 characters")
		os.Exit(1)
	}

	lis, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
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
	shutdown.Unlock()

	// Report the actual port so a caller that passed 0 can discover it.
	fmt.Printf("nekobox_core listening on %v\n", lis.Addr())
	log.Printf("nekobox_core grpc server listening at %v\n", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
