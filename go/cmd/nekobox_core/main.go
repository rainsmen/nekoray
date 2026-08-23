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

	// Parse args: nekobox_core nekobox [--token TOKEN] [--port PORT] [--debug]
	//
	// Prefer passing the token via the NEKORAY_AUTH_TOKEN environment variable —
	// command-line arguments are visible to any process that can read /proc.
	if len(os.Args) > 1 && os.Args[1] == "nekobox" {
		token, port := parseArgs(os.Args[2:])
		grpc_server.SetVersion(CoreVersion)
		grpc_server.SetProxyHttpClientFactory(resolveProxyClient)
		grpc_server.RunCore(token, port, Debug, &server{})
		return
	}

	fmt.Println("usage: nekobox_core nekobox [--token TOKEN] [--port PORT] [--debug]")
	fmt.Printf("       (token may also be supplied via $%s)\n", grpc_server.TokenEnvVar)
	os.Exit(2)
}

// parseArgs extracts --token, --port, --debug from the argument list.
func parseArgs(args []string) (token string, port int) {
	port = 19821 // default gRPC port
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--token":
			if i+1 < len(args) {
				token = args[i+1]
				i++
			}
		case "--port":
			if i+1 < len(args) {
				if p, err := strconv.Atoi(args[i+1]); err == nil {
					port = p
				}
				i++
			}
		case "--debug":
			Debug = true
		}
	}
	return
}
