// Command migrator converts old nekoray configuration (profiles/*.json,
// groups/*.json, routing) into the format expected by the new Flutter-based
// client.
//
// Phase-1 MVP: reads the old JSON files and re-emits them with normalized
// fields, preserving backward compatibility. No format change is needed yet
// (the Dart data classes read the same JSON), so this tool mainly validates
// and reports.
//
// Usage:
//   migrator -src ~/.config/nekoray/ -dst ./new_config/ [-dry-run]
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	src := flag.String("src", "", "source config directory (old nekoray)")
	dst := flag.String("dst", "", "destination directory (new format)")
	dryRun := flag.Bool("dry-run", false, "only report, do not write")
	flag.Parse()

	if *src == "" || *dst == "" {
		fmt.Fprintln(os.Stderr, "usage: migrator -src <old_dir> -dst <new_dir> [-dry-run]")
		os.Exit(1)
	}

	if err := os.MkdirAll(*dst, 0755); err != nil {
		fatal("create dst: %v", err)
	}

	stats := struct {
		profiles int
		groups    int
		routing   int
		skipped   int
	}{}

	// migrate profiles
	profilesDir := filepath.Join(*src, "profiles")
	if entries, err := os.ReadDir(profilesDir); err == nil {
		dstProfiles := filepath.Join(*dst, "profiles")
		if !*dryRun {
			os.MkdirAll(dstProfiles, 0755)
		}
		for _, e := range entries {
			if e.IsDir() || filepath.Ext(e.Name()) != ".json" {
				continue
			}
			if _, err := migrateJSON(filepath.Join(profilesDir, e.Name()), filepath.Join(dstProfiles, e.Name()), *dryRun); err != nil {
				fmt.Fprintf(os.Stderr, "skip profile %s: %v\n", e.Name(), err)
				stats.skipped++
				continue
			}
			stats.profiles++
		}
	}

	// migrate groups
	groupsDir := filepath.Join(*src, "groups")
	if entries, err := os.ReadDir(groupsDir); err == nil {
		dstGroups := filepath.Join(*dst, "groups")
		if !*dryRun {
			os.MkdirAll(dstGroups, 0755)
		}
		for _, e := range entries {
			if e.IsDir() || filepath.Ext(e.Name()) != ".json" {
				continue
			}
			if _, err := migrateJSON(filepath.Join(groupsDir, e.Name()), filepath.Join(dstGroups, e.Name()), *dryRun); err != nil {
				fmt.Fprintf(os.Stderr, "skip group %s: %v\n", e.Name(), err)
				stats.skipped++
				continue
			}
			stats.groups++
		}
	}

	// migrate routing files (routing_*.json)
	if entries, err := os.ReadDir(*src); err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			name := e.Name()
			if !startsWith(name, "routing_") || filepath.Ext(name) != ".json" {
				continue
			}
			if _, err := migrateJSON(filepath.Join(*src, name), filepath.Join(*dst, name), *dryRun); err != nil {
				fmt.Fprintf(os.Stderr, "skip routing %s: %v\n", name, err)
				stats.skipped++
				continue
			}
			stats.routing++
		}
	}

	fmt.Printf("migration done: profiles=%d groups=%d routing=%d skipped=%d\n",
		stats.profiles, stats.groups, stats.routing, stats.skipped)
	if *dryRun {
		fmt.Println("(dry-run: no files written)")
	}
}

// migrateJSON reads a JSON file, normalizes it (re-encode with indent), and
// writes to dst. Returns true if the JSON was valid.
func migrateJSON(src, dst string, dryRun bool) (bool, error) {
	data, err := os.ReadFile(src)
	if err != nil {
		return false, err
	}
	var v interface{}
	if err := json.Unmarshal(data, &v); err != nil {
		return false, fmt.Errorf("invalid json: %w", err)
	}
	out, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return false, err
	}
	if dryRun {
		return true, nil
	}
	return true, os.WriteFile(dst, out, 0644)
}

func startsWith(s, prefix string) bool {
	return len(s) >= len(prefix) && s[:len(prefix)] == prefix
}

func fatal(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "migrator: "+format+"\n", args...)
	os.Exit(1)
}
