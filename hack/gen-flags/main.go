// Command gen-flags renders the flags of the controller into the configuration page.
//
// It runs the binary with --help and rewrites the block between the two markers, so the table
// cannot drift from the code.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

const (
	startMarker = "<!-- flags:start -->"
	endMarker   = "<!-- flags:end -->"
)

type row struct {
	name    string
	usage   string
	def     string
}

func main() {
	binary := flag.String("binary", "", "Controller binary to ask for its flags")
	file := flag.String("file", "", "Markdown file to rewrite")
	flag.Parse()

	if *binary == "" || *file == "" {
		fmt.Fprintln(os.Stderr, "usage: gen-flags -binary <path> -file <markdown>")
		os.Exit(2)
	}

	out, err := exec.Command(*binary, "--help").CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "cannot read the flags of %s: %v\n", *binary, err)
		os.Exit(1)
	}

	table := render(parse(string(out)))
	content, err := os.ReadFile(*file)
	if err != nil {
		fmt.Fprintf(os.Stderr, "cannot read %s: %v\n", *file, err)
		os.Exit(1)
	}

	updated, err := splice(string(content), table)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	if err := os.WriteFile(*file, []byte(updated), 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "cannot write %s: %v\n", *file, err)
		os.Exit(1)
	}

	fmt.Printf("%d flags written to %s\n", strings.Count(table, "\n")-2, *file)
}

// parse reads the two-line format of the flag package: the flag with its type, then the usage.
func parse(help string) []row {
	header := regexp.MustCompile(`^  -([\w.-]+)(?: (\w+))?$`)
	defaultValue := regexp.MustCompile(`\s*\(default (.+)\)$`)

	var rows []row
	var current *row

	for _, line := range strings.Split(help, "\n") {
		if m := header.FindStringSubmatch(line); m != nil {
			if current != nil {
				rows = append(rows, *current)
			}
			typ := m[2]
			current = &row{name: m[1], def: defaultFor(typ)}
			continue
		}

		if current != nil && strings.HasPrefix(line, "    ") {
			usage := strings.TrimSpace(line)
			if m := defaultValue.FindStringSubmatch(usage); m != nil {
				current.def = strings.ReplaceAll(m[1], `"`, "")
				usage = strings.TrimSpace(usage[:len(usage)-len(m[0])])
			}
			if current.usage != "" {
				current.usage += " "
			}
			current.usage += usage
		}
	}

	if current != nil {
		rows = append(rows, *current)
	}

	return rows
}

func defaultFor(typ string) string {
	if typ == "" {
		return "false"
	}
	return "-"
}

func render(rows []row) string {
	var b strings.Builder
	b.WriteString("| Flag | Description | Default |\n")
	b.WriteString("| --- | --- | --- |\n")
	for _, r := range rows {
		fmt.Fprintf(&b, "| `--%s` | %s | %s |\n", r.name, escape(r.usage), escape(r.def))
	}
	return b.String()
}

func escape(s string) string {
	if s == "" {
		return "-"
	}
	return strings.ReplaceAll(s, "|", `\|`)
}

func splice(content, table string) (string, error) {
	start := strings.Index(content, startMarker)
	end := strings.Index(content, endMarker)
	if start == -1 || end == -1 || end < start {
		return "", fmt.Errorf("markers %s and %s not found, in that order", startMarker, endMarker)
	}

	return content[:start+len(startMarker)] + "\n" + table + content[end:], nil
}
