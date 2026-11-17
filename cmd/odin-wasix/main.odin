package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

VERSION :: "0.1.0"

main :: proc() {
	args := os.args
	if len(args) < 2 {
		print_usage()
		os.exit(1)
	}

	command := args[1]
	switch command {
	case "new":
		if len(args) < 3 {
			fmt.println("Error: Project name required. Usage: odin-wasix new <name>")
			os.exit(1)
		}
		cmd_new(args[2])
	case "build":
		cmd_build(args[2:])
	case "run", "dev":
		cmd_run(args[2:])
	case "test":
		cmd_test(args[2:])
	case "deploy":
		cmd_deploy()
	case "version", "-v", "--version":
		fmt.printfln("odin-wasix version %s (WASIX 32-bit v1)", VERSION)
	case "help", "-h", "--help":
		print_usage()
	case:
		fmt.printfln("Unknown command: %s\n", command)
		print_usage()
		os.exit(1)
	}
}

print_usage :: proc() {
	fmt.println("⚡ odin-wasix: First-class Tooling for Odin on WASIX & Wasmer Edge")
	fmt.println()
	fmt.println("Usage:")
	fmt.println("  odin-wasix <command> [arguments]")
	fmt.println()
	fmt.println("Commands:")
	fmt.println("  new <name>    Scaffold a new, ready-to-run Odin WASIX project")
	fmt.println("  build         Compile Odin source to an optimized WASIX binary (.wasm)")
	fmt.println("  run / dev     Build and launch application in Wasmer with full networking")
	fmt.println("  test          Execute automated end-to-end integration test suite")
	fmt.println("  deploy        Deploy application directly to Wasmer Edge (wasmer.app)")
	fmt.println("  version       Print odin-wasix version")
	fmt.println("  help          Show this help message")
}

find_wasix_collection :: proc() -> string {
	candidates := [?]string{
		"pkg/wasix",
		"../pkg/wasix",
		"../../pkg/wasix",
	}

	if env_path := os.get_env("ODIN_WASIX_PATH", context.temp_allocator); len(env_path) > 0 {
		p := fmt.tprintf("%s/pkg/wasix", env_path)
		if os.is_dir(p) do return p
	}

	for c in candidates {
		if os.is_dir(c) do return c
	}

	return ""
}

cmd_new :: proc(name: string) {
	if os.exists(name) {
		fmt.printfln("Error: Directory '%s' already exists.", name)
		os.exit(1)
	}

	fmt.printfln("✨ Scaffolding new Odin WASIX project '%s' ...", name)

	os.make_directory(name)
	os.make_directory(fmt.tprintf("%s/public", name))
	os.make_directory(fmt.tprintf("%s/bin", name))

	_ = os.write_entire_file(fmt.tprintf("%s/main.odin", name), TEMPLATE_MAIN_ODIN)
	_ = os.write_entire_file(fmt.tprintf("%s/public/index.html", name), TEMPLATE_INDEX_HTML)
	_ = os.write_entire_file(fmt.tprintf("%s/public/style.css", name), TEMPLATE_STYLE_CSS)

	wasmer_toml := fmt.tprintf(TEMPLATE_WASMER_TOML, name)
	_ = os.write_entire_file(fmt.tprintf("%s/wasmer.toml", name), wasmer_toml)

	app_yaml := fmt.tprintf(TEMPLATE_APP_YAML, name)
	_ = os.write_entire_file(fmt.tprintf("%s/app.yaml", name), app_yaml)

	_ = os.write_entire_file(fmt.tprintf("%s/.gitignore", name), TEMPLATE_GITIGNORE)

	readme := fmt.tprintf("# %s\n\nHigh-performance Odin WASIX Webserver running on Wasmer Edge.\n\n### Running Locally\n```bash\nodin-wasix run\n```\n", name)
	_ = os.write_entire_file(fmt.tprintf("%s/README.md", name), readme)

	fmt.println("✓ Project created successfully!")
	fmt.println()
	fmt.println("Next steps:")
	fmt.printfln("  cd %s", name)
	fmt.println("  odin-wasix run")
}

cmd_build :: proc(args: []string) {
	src := ""
	out := "bin/server.wasm"
	opt := "speed"

	for i := 0; i < len(args); i += 1 {
		arg := args[i]
		if strings.has_prefix(arg, "-out:") {
			out = arg[len("-out:"):]
		} else if strings.has_prefix(arg, "-opt:") {
			opt = arg[len("-opt:"):]
		} else if strings.has_prefix(arg, "-o:") {
			opt = arg[len("-o:"):]
		} else if src == "" {
			src = arg
		}
	}

	if src == "" {
		if os.exists("main.odin") {
			src = "."
		} else if os.is_dir("examples/webserver") {
			src = "examples/webserver"
		} else {
			src = "."
		}
	}

	out_dir := filepath.dir(out)
	if len(out_dir) > 0 && !os.exists(out_dir) {
		os.make_directory(out_dir)
	}

	cmd_args := make([dynamic]string, context.temp_allocator)
	append(&cmd_args, "odin", "build", src, "-target:wasi_wasm32", fmt.tprintf("-o:%s", opt), fmt.tprintf("-out:%s", out))

	col_path := find_wasix_collection()
	if len(col_path) > 0 {
		append(&cmd_args, fmt.tprintf("-collection:wasix=%s", col_path))
	}

	fmt.printfln("[BUILD] Compiling %s to %s (-target:wasi_wasm32 -o:%s) ...", src, out, opt)

	desc := os.Process_Desc{
		command = cmd_args[:],
	}

	start := time.now()
	state, stdout, stderr, err := os.process_exec(desc, context.temp_allocator)
	if err != nil || state.exit_code != 0 {
		fmt.printfln("[BUILD FAILED] exit_code=%d\n%s\n%s", state.exit_code, string(stdout), string(stderr))
		os.exit(1)
	}
	elapsed := time.since(start)

	file_size := 0
	if data, read_err := os.read_entire_file(out, context.temp_allocator); read_err == nil {
		file_size = len(data) / 1024
	}

	fmt.printfln("[BUILD SUCCESS] %s (%d KB) compiled in %v", out, file_size, elapsed)
}

cmd_run :: proc(args: []string) {
	cmd_build(args)

	port := "8080"
	wasm := "bin/server.wasm"

	run_args := make([dynamic]string, context.temp_allocator)
	append(&run_args, "wasmer", "run", "--net", "--env", fmt.tprintf("PORT=%s", port))

	if os.is_dir("public") {
		append(&run_args, "--volume", "public:public")
	} else if os.is_dir("examples/webserver/public") {
		append(&run_args, "--volume", "examples/webserver/public:public")
	}

	append(&run_args, wasm)

	fmt.printfln("[RUN] Launching Wasmer WASIX on http://localhost:%s ...", port)

	desc := os.Process_Desc{
		command = run_args[:],
	}
	state, _, _, _ := os.process_exec(desc, context.temp_allocator)
	os.exit(state.exit_code)
}

cmd_test :: proc(args: []string) {
	// Delegate to the comprehensive bash test runner which tests real network HTTP curl connections
	desc := os.Process_Desc{
		command = []string{"./odin-wasix", "test"},
	}
	state, stdout, stderr, _ := os.process_exec(desc, context.temp_allocator)
	fmt.print(string(stdout))
	if len(stderr) > 0 do fmt.eprint(string(stderr))
	os.exit(state.exit_code)
}

cmd_deploy :: proc() {
	cmd_build({"examples/webserver", "-out:bin/server.wasm", "-opt:speed"})

	fmt.println("[DEPLOY] Invoking 'wasmer deploy' to Wasmer Edge (wasmer.app) ...")
	desc := os.Process_Desc{
		command = []string{"wasmer", "deploy"},
	}
	state, stdout, stderr, _ := os.process_exec(desc, context.temp_allocator)
	fmt.print(string(stdout))
	if len(stderr) > 0 do fmt.eprint(string(stderr))
	os.exit(state.exit_code)
}

// -----------------------------------------------------------------------------
// Template strings
// -----------------------------------------------------------------------------

TEMPLATE_MAIN_ODIN: string : `package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"

import "wasix:http"
import "wasix:sys"

start_time: time.Time

main :: proc() {
	start_time = time.now()

	port: u16 = 8080
	if port_env := os.get_env("PORT", context.temp_allocator); len(port_env) > 0 {
		if p, ok := strconv.parse_int(port_env); ok && p > 0 && p <= 65535 {
			port = u16(p)
		}
	}

	host := "0.0.0.0"

	server: http.Server
	http.server_init(&server)
	defer http.server_destroy(&server)

	// Static asset serving
	http.serve_static(&server.router, "/public", "public")

	// Root landing route
	http.get(&server.router, "/", proc(req: ^http.Request, res: ^http.Response) {
		if html, err := os.read_entire_file("public/index.html", context.temp_allocator); err == nil {
			http.response_html(res, string(html))
			return
		}
		http.response_html(res, "<h1>⚡ Odin WASIX Webserver</h1><p>Running on Wasmer Edge</p>")
	})

	// Health check
	http.get(&server.router, "/api/v1/health", proc(req: ^http.Request, res: ^http.Response) {
		elapsed := time.since(start_time)
		http.response_json(res, fmt.tprintf("{{\"status\":\"healthy\",\"uptime_seconds\":%.3f}}", time.duration_seconds(elapsed)))
	})

	// System metrics
	http.get(&server.router, "/api/v1/system", proc(req: ^http.Request, res: ^http.Response) {
		pid: sys.pid_t
		sys.proc_id(&pid)

		parallelism: uint
		sys.thread_parallelism(&parallelism)

		http.response_json(res, fmt.tprintf("{{\"runtime\":\"wasix_32v1\",\"language\":\"odin\",\"pid\":%d,\"hardware_threads\":%d}}", pid, parallelism))
	})

	// Echo POST endpoint
	http.post(&server.router, "/api/v1/echo", proc(req: ^http.Request, res: ^http.Response) {
		body := string(req.body)
		if len(body) == 0 do body = "{}"
		http.response_json(res, fmt.tprintf("{{\"echo\":%s}}", body))
	})

	fmt.printfln("[INIT] Starting Odin WASIX server on %s:%d ...", host, port)
	http.server_listen_and_serve(&server, host, port)
}
`

TEMPLATE_INDEX_HTML: string : `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Odin WASIX Web Server</title>
  <link rel="stylesheet" href="/public/style.css">
</head>
<body>
  <div class="container">
    <header>
      <div class="badge">Wasmer Edge Native</div>
      <h1>⚡ Odin WASIX Web Server</h1>
      <p class="subtitle">Ultra-lightweight WebAssembly server compiled with Odin.</p>
    </header>
    <div class="grid">
      <div class="card">
        <h3>WASIX Diagnostics</h3>
        <button id="btnDiag" class="btn">Fetch Metrics</button>
        <pre id="diagOutput">Click above to query /api/v1/system</pre>
      </div>
      <div class="card">
        <h3>Health Probe</h3>
        <button id="btnHealth" class="btn">Check Health</button>
        <pre id="healthOutput">Click above to query /api/v1/health</pre>
      </div>
    </div>
  </div>
  <script>
    document.getElementById('btnDiag').onclick = async () => {
      const res = await fetch('/api/v1/system');
      document.getElementById('diagOutput').textContent = JSON.stringify(await res.json(), null, 2);
    };
    document.getElementById('btnHealth').onclick = async () => {
      const res = await fetch('/api/v1/health');
      document.getElementById('healthOutput').textContent = JSON.stringify(await res.json(), null, 2);
    };
  </script>
</body>
</html>
`

TEMPLATE_STYLE_CSS: string : `:root {
  --bg: #0b0f19; --surface: #151d2f; --border: #232f48; --accent: #38bdf8;
  --accent-hover: #0284c7; --text: #f1f5f9; --muted: #94a3b8; --code-bg: #070a10;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, sans-serif; background: var(--bg); color: var(--text); padding: 2rem 1rem; }
.container { max-width: 800px; margin: 0 auto; }
header { text-align: center; margin-bottom: 2rem; }
.badge { display: inline-block; background: var(--accent-hover); color: #fff; font-size: 0.75rem; font-weight: 700; padding: 0.25rem 0.75rem; border-radius: 9999px; text-transform: uppercase; }
h1 { font-size: 2.25rem; color: var(--accent); margin: 0.5rem 0; }
.subtitle { color: var(--muted); }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem; }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 1.5rem; }
.card h3 { color: var(--accent); margin-bottom: 0.5rem; }
.btn { background: var(--accent); color: #0b0f19; border: none; font-weight: 600; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; }
.btn:hover { background: var(--accent-hover); color: #fff; }
pre { background: var(--code-bg); border: 1px solid var(--border); border-radius: 6px; padding: 0.75rem; font-family: monospace; font-size: 0.85rem; color: #38bdf8; margin-top: 0.75rem; }
`

TEMPLATE_WASMER_TOML: string : `[package]
name = "%s"
version = "0.1.0"
description = "High-performance Odin WASIX Webserver"
license = "MIT"

[[module]]
name = "server"
source = "bin/server.wasm"
abi = "wasi"

[[command]]
name = "server"
module = "server"
runner = "https://webc.org/runner/wasi"

[command.annotations.wasi]
env = ["PORT=8080"]

[fs]
"/public" = "public"
`

TEMPLATE_APP_YAML: string : `---
name: %s
package: .
capabilities:
  insecure_allow_all_network: true
`

TEMPLATE_GITIGNORE: string : `bin/
*.wasm
.DS_Store
`
