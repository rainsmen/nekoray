package grpc_server

import (
	"context"
	"encoding/hex"
	"fmt"
	"grpc_server/gen"
	"io"
	"log"
	"math"
	"net"
	"net/http"
	"strings"
	"time"
)

const (
	KiB = 1024
	MiB = 1024 * KiB
)

func getBetweenStr(str, start, end string) string {
	n := strings.Index(str, start)
	if n == -1 {
		n = 0
	}
	str = string([]byte(str)[n:])
	m := strings.Index(str, end)
	if m == -1 {
		m = len(str)
	}
	str = string([]byte(str)[:m])
	return str[len(start):]
}

// DoFullTest runs the full connectivity test (latency, UDP, IP, speed).
//
// The instance parameter is the sing-box *box.Box, but to avoid a hard
// dependency on sing-box here we accept interface{} and use the injected
// proxyHttpClient factory (set via SetProxyHttpClientFactory by the core).
func DoFullTest(ctx context.Context, in *gen.TestReq, instance interface{}) (out *gen.TestResp, _ error) {
	out = &gen.TestResp{}
	httpClient := proxyHttpClient()

	// Latency
	var latency string
	if in.FullLatency {
		t := urlLatency(httpClient, in.Url, int(in.Timeout))
		out.Ms = int32(t)
		if t > 0 {
			latency = fmt.Sprintf("%dms", t)
		} else {
			latency = "Error"
		}
	}

	// UDP Latency
	var udpLatency string
	if in.FullUdpLatency {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second*3)
		result := make(chan string)

		go func() {
			var startTime = time.Now()
			pc, err := udpDial(ctx, instance, "8.8.8.8:53")
			if err == nil {
				defer pc.Close()
				dnsPacket, _ := hex.DecodeString("0000010000010000000000000377777706676f6f676c6503636f6d0000010001")
				_, err = pc.Write(dnsPacket)
				if err == nil {
					var buf [1400]byte
					_, err = pc.Read(buf[:])
				}
			}
			if err == nil {
				var endTime = time.Now()
				result <- fmt.Sprintf("%dms", endTime.Sub(startTime).Abs().Milliseconds())
			} else {
				log.Println("UDP Latency test error:", err)
				result <- "Error"
			}
			close(result)
		}()

		select {
		case <-ctx.Done():
			udpLatency = "Timeout"
		case r := <-result:
			udpLatency = r
		}
		cancel()
	}

	// Entry IP
	var in_ip string
	if in.FullInOut {
		if addr, err := net.ResolveIPAddr("ip", in.InAddress); err == nil {
			in_ip = addr.String()
		} else {
			in_ip = err.Error()
		}
	}

	// Exit IP
	var out_ip string
	if in.FullInOut {
		resp, err := httpClient.Get("https://www.cloudflare.com/cdn-cgi/trace")
		if err == nil {
			b, _ := io.ReadAll(resp.Body)
			out_ip = getBetweenStr(string(b), "ip=", "\n")
			resp.Body.Close()
		} else {
			out_ip = "Error"
		}
	}

	// Download speed
	var speed string
	if in.FullSpeed {
		if in.FullSpeedTimeout <= 0 {
			in.FullSpeedTimeout = 30
		}

		ctx, cancel := context.WithTimeout(context.Background(), time.Second*time.Duration(in.FullSpeedTimeout))
		result := make(chan string)
		var bodyClose io.Closer

		go func() {
			req, _ := http.NewRequestWithContext(ctx, "GET", in.FullSpeedUrl, nil)
			resp, err := httpClient.Do(req)
			if err == nil && resp != nil && resp.Body != nil {
				bodyClose = resp.Body
				defer resp.Body.Close()

				timeStart := time.Now()
				n, _ := io.Copy(io.Discard, resp.Body)
				timeEnd := time.Now()

				duration := math.Max(timeEnd.Sub(timeStart).Seconds(), 0.000001)
				resultSpeed := (float64(n) / duration) / MiB
				result <- fmt.Sprintf("%.2fMiB/s", resultSpeed)
			} else {
				result <- "Error"
			}
			close(result)
		}()

		select {
		case <-ctx.Done():
			speed = "Timeout"
		case s := <-result:
			speed = s
		}

		cancel()
		if bodyClose != nil {
			bodyClose.Close()
		}
	}

	fr := make([]string, 0)
	if latency != "" {
		fr = append(fr, fmt.Sprintf("Latency: %s", latency))
	}
	if udpLatency != "" {
		fr = append(fr, fmt.Sprintf("UDPLatency: %s", udpLatency))
	}
	if speed != "" {
		fr = append(fr, fmt.Sprintf("Speed: %s", speed))
	}
	if in_ip != "" {
		fr = append(fr, fmt.Sprintf("In: %s", in_ip))
	}
	if out_ip != "" {
		fr = append(fr, fmt.Sprintf("Out: %s", out_ip))
	}

	out.FullReport = strings.Join(fr, " / ")
	return
}

// urlLatency measures HTTP request latency in milliseconds.
func urlLatency(client *http.Client, target string, timeout int) int {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeout)*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "GET", target, nil)
	if err != nil {
		return 0
	}
	start := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		return 0
	}
	defer resp.Body.Close()
	return int(time.Since(start).Milliseconds())
}

// udpDial dials a UDP connection through the proxy instance if available.
// Uses the injected factory; falls back to direct dialing.
var udpDial func(ctx context.Context, instance interface{}, addr string) (net.Conn, error) =
	func(ctx context.Context, instance interface{}, addr string) (net.Conn, error) {
		var d net.Dialer
		return d.DialContext(ctx, "udp", addr)
	}

// SetUdpDialFunc allows the core to inject a UDP dialer that routes
// through the sing-box instance.
func SetUdpDialFunc(f func(ctx context.Context, instance interface{}, addr string) (net.Conn, error)) {
	udpDial = f
}
