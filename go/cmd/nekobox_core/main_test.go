package main

import (
	"testing"
)

func TestParseArgs(t *testing.T) {
	tests := []struct {
		name      string
		args      []string
		wantToken string
		wantPort  int
		wantErr   bool
	}{
		{
			name:      "default args",
			args:      []string{},
			wantToken: "",
			wantPort:  19821,
			wantErr:   false,
		},
		{
			name:      "with token and port",
			args:      []string{"--token", "mysecrettoken123", "--port", "12345"},
			wantToken: "mysecrettoken123",
			wantPort:  12345,
			wantErr:   false,
		},
		{
			name:      "port 0 ephemeral",
			args:      []string{"--port", "0", "--token", "tok"},
			wantToken: "tok",
			wantPort:  0,
			wantErr:   false,
		},
		{
			name:      "with debug",
			args:      []string{"--debug", "--port", "8080"},
			wantToken: "",
			wantPort:  8080,
			wantErr:   false,
		},
		{
			name:    "missing token value",
			args:    []string{"--token"},
			wantErr: true,
		},
		{
			name:    "missing port value",
			args:    []string{"--port"},
			wantErr: true,
		},
		{
			name:    "invalid port value",
			args:    []string{"--port", "notanumber"},
			wantErr: true,
		},
		{
			name:    "unknown flag",
			args:    []string{"--unknown-flag"},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			token, port, err := parseArgs(tt.args)
			if (err != nil) != tt.wantErr {
				t.Fatalf("parseArgs() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr {
				if token != tt.wantToken {
					t.Errorf("token = %q, want %q", token, tt.wantToken)
				}
				if port != tt.wantPort {
					t.Errorf("port = %d, want %d", port, tt.wantPort)
				}
			}
		})
	}
}
