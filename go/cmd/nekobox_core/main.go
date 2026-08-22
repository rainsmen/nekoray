package main

import (
	"fmt"
	"os"

	"grpc_server"

	"github.com/matsuridayo/libneko/neko_common"
	"github.com/sagernet/sing-box/constant"
)

func main() {
	fmt.Println("sing-box:", constant.Version, "NekoBox:", neko_common.Version_neko)
	fmt.Println()

	// nekobox_core: run as gRPC server for the GUI
	if len(os.Args) > 1 && os.Args[1] == "nekobox" {
		neko_common.RunMode = neko_common.RunMode_NekoBox_Core
		grpc_server.RunCore(setupCore, &server{})
		return
	}

	// Otherwise, fall back to a basic sing-box CLI passthrough.
	//
	// NOTE: upstream sing-box (>= 1.11) ships cmd/sing-box as package main
	// with no exported entry point, so we no longer delegate to boxmain.Main().
	// A minimal run command is provided for ad-hoc usage; for the full CLI
	// users should use the official sing-box binary.
	fmt.Println("usage: nekobox_core nekobox [--token TOKEN] [--port PORT] [--debug]")
	os.Exit(0)
}
