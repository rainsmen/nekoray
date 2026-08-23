package main

import (
	"fmt"
	"os"
	"strconv"

	"grpc_server"

	"github.com/sagernet/sing-box/constant"
)

func main() {
	fmt.Printf("sing-box: %s  NekoBox core: %s\n", constant.Version, CoreVersion)
	fmt.Println()

	// Parse args: nekobox_core [nekobox] [--token TOKEN] [--port PORT] [--debug]
	//
	// Prefer passing the token via the NEKORAY_AUTH_TOKEN environment variable —
	// command-line arguments are visible to any process that can read /proc.
	args := os.Args[1:]
	if len(args) > 0 && args[0] == "nekobox" {
		args = args[1:]
	}

	token, port, err := parseArgs(args)
	if err != nil {
		fmt.Println("usage: nekobox_core [nekobox] [--token TOKEN] [--port PORT] [--debug]")
		fmt.Printf("       (token may also be supplied via $%s)\n", grpc_server.TokenEnvVar)
		os.Exit(2)
	}

	grpc_server.SetVersion(CoreVersion)
	grpc_server.SetProxyHttpClientFactory(resolveProxyClient)
	grpc_server.SetUdpDialFunc(resolveProxyUDPDialer)
	grpc_server.SetShutdownHook(shutdownCoreInstance)
	grpc_server.RunCore(token, port, Debug, &server{})
}

// parseArgs extracts --token, --port, --debug from the argument list.
func parseArgs(args []string) (token string, port int, err error) {
	port = 19821 // default gRPC port
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--token":
			if i+1 < len(args) {
				token = args[i+1]
				i++
			} else {
				return "", 0, fmt.Errorf("missing argument for --token")
			}
		case "--port":
			if i+1 < len(args) {
				if p, pErr := strconv.Atoi(args[i+1]); pErr == nil {
					port = p
				} else {
					return "", 0, fmt.Errorf("invalid port %q: %w", args[i+1], pErr)
				}
				i++
			} else {
				return "", 0, fmt.Errorf("missing argument for --port")
			}
		case "--debug":
			Debug = true
		default:
			if len(args[i]) > 0 && args[i][0] == '-' {
				return "", 0, fmt.Errorf("unknown flag: %s", args[i])
			}
		}
	}
	return token, port, nil
}
