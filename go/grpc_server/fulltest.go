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
		return ""
	}
	str = str[n:]
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
		udpCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		result := make(chan string, 1)

		go func() {
			startTime := time.Now()
			pc, err := udpDial(udpCtx, instance, "8.8.8.8:53")
			if err == nil && pc != nil {
				defer pc.Close()
				// Context cancellation does not interrupt Read on every net.Conn
				// implementation, so bound the read itself as well.
				if deadline, ok := udpCtx.Deadline(); ok {
					_ = pc.SetDeadline(deadline)
				}
				dnsPacket, decodeErr := hex.DecodeString("0000010000010000000000000377777706676f6f676c6503636f6d0000010001")
				if decodeErr != nil {
					err = decodeErr
				} else {
					_, err = pc.Write(dnsPacket)
					if err == nil {
						var buf [1400]byte
						_, err = pc.Read(buf[:])
					}
				}
			} else if err == nil {
				err = fmt.Errorf("UDP dial returned a nil connection")
			}
			resultValue := "Error"
			if err == nil {
				resultValue = fmt.Sprintf("%dms", time.Since(startTime).Abs().Milliseconds())
			} else {
				log.Println("UDP Latency test error:", err)
			}
			// Buffered result ensures the worker can finish even when the
			// caller has already observed the timeout.
			result <- resultValue
		}()

		select {
		case udpLatency = <-result:
		case <-udpCtx.Done():
			udpLatency = "Timeout"
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
		if err == nil && resp != nil && resp.Body != nil {
			defer resp.Body.Close()
			b, readErr := io.ReadAll(resp.Body)
			if readErr == nil {
				out_ip = getBetweenStr(string(b), "ip=", "\n")
			} else {
				out_ip = "Error"
			}
		} else {
			out_ip = "Error"
		}
	}

	// Download speed
	var speed string
	if in.FullSpeed {
		timeout := in.FullSpeedTimeout
		if timeout <= 0 {
			timeout = 30
		}

		speedCtx, cancel := context.WithTimeout(ctx, time.Second*time.Duration(timeout))
		result := make(chan string, 1)

		go func() {
			req, err := http.NewRequestWithContext(speedCtx, "GET", in.FullSpeedUrl, nil)
			if err == nil {
				var resp *http.Response
				resp, err = httpClient.Do(req)
				if resp != nil && resp.Body != nil {
					defer resp.Body.Close()
				}
				if err == nil && resp != nil && resp.Body != nil {
					timeStart := time.Now()
					n, copyErr := io.Copy(io.Discard, resp.Body)
					timeEnd := time.Now()
					if copyErr != nil {
						err = copyErr
					} else {
						duration := math.Max(timeEnd.Sub(timeStart).Seconds(), 0.000001)
						result <- fmt.Sprintf("%.2fMiB/s", (float64(n)/duration)/MiB)
						return
					}
				} else if err == nil {
					err = fmt.Errorf("speed test returned an empty response")
				}
			}
			if err != nil {
				log.Println("Download speed test error:", err)
			}
			// Buffered result avoids blocking the worker after a timeout. The
			// response body is always closed by this goroutine's defer.
			result <- "Error"
		}()

		select {
		case speed = <-result:
		case <-speedCtx.Done():
			speed = "Timeout"
		}
		cancel()
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
var udpDial func(ctx context.Context, instance interface{}, addr string) (net.Conn, error) = func(ctx context.Context, instance interface{}, addr string) (net.Conn, error) {
	var d net.Dialer
	return d.DialContext(ctx, "udp", addr)
}

// SetUdpDialFunc allows the core to inject a UDP dialer that routes
// through the sing-box instance.
func SetUdpDialFunc(f func(ctx context.Context, instance interface{}, addr string) (net.Conn, error)) {
	udpDial = f
}
