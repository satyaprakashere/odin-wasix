package main

const templateMainOdin = `package main

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

	// Mount static file serving
	http.serve_static(&server.router, "/public", "public")

	// Root landing route
	http.get(&server.router, "/", proc(req: ^http.Request, res: ^http.Response) {
		if html_data, err := os.read_entire_file("public/index.html", context.temp_allocator); err == nil {
			http.response_html(res, string(html_data))
			return
		}
		http.response_html(res, "<h1>⚡ Odin WASIX Webserver</h1><p>Powered by Wasmer Edge</p>")
	})

	// Health check endpoint
	http.get(&server.router, "/api/v1/health", proc(req: ^http.Request, res: ^http.Response) {
		elapsed := time.since(start_time)
		http.response_json(res, fmt.tprintf("{{\"status\":\"healthy\",\"uptime_seconds\":%.3f}}", time.duration_seconds(elapsed)))
	})

	// System metrics querying WASIX kernel
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

const templateIndexHTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Odin WASIX Web Server</title>
  <link rel="stylesheet" href="/public/style.css">
</head>
<body>
  <div class="container">
    <header>
      <div class="badge">Wasmer Edge Native</div>
      <h1>⚡ Odin WASIX Web Server</h1>
      <p class="subtitle">Ultra-lightweight, instant-start WebAssembly server running on WASIX.</p>
    </header>

    <div class="grid">
      <div class="card">
        <h3>WASIX Diagnostics</h3>
        <p>Query WASIX kernel directly from Odin:</p>
        <button id="btnDiag" class="btn">Fetch Metrics</button>
        <pre id="diagOutput">Click above to query /api/v1/system</pre>
      </div>

      <div class="card">
        <h3>Health Probe</h3>
        <p>Real-time uptime check:</p>
        <button id="btnHealth" class="btn">Check Health</button>
        <pre id="healthOutput">Click above to query /api/v1/health</pre>
      </div>
    </div>

    <footer>
      <p>Compiled with <strong>Odin</strong> &bull; Running on <strong>Wasmer Edge</strong></p>
    </footer>
  </div>

  <script>
    document.getElementById('btnDiag').onclick = async () => {
      const res = await fetch('/api/v1/system');
      const data = await res.json();
      document.getElementById('diagOutput').textContent = JSON.stringify(data, null, 2);
    };

    document.getElementById('btnHealth').onclick = async () => {
      const res = await fetch('/api/v1/health');
      const data = await res.json();
      document.getElementById('healthOutput').textContent = JSON.stringify(data, null, 2);
    };
  </script>
</body>
</html>
`

const templateStyleCSS = `:root {
  --bg: #0b0f19;
  --surface: #151d2f;
  --border: #232f48;
  --accent: #38bdf8;
  --accent-hover: #0284c7;
  --text: #f1f5f9;
  --muted: #94a3b8;
  --code-bg: #070a10;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); padding: 2rem 1rem; }
.container { max-width: 800px; margin: 0 auto; }
header { text-align: center; margin-bottom: 2rem; }
.badge { display: inline-block; background: var(--accent-hover); color: #fff; font-size: 0.75rem; font-weight: 700; padding: 0.25rem 0.75rem; border-radius: 9999px; margin-bottom: 0.5rem; text-transform: uppercase; }
h1 { font-size: 2.25rem; color: var(--accent); margin-bottom: 0.5rem; }
.subtitle { color: var(--muted); }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem; }
@media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 1.5rem; }
.card h3 { color: var(--accent); margin-bottom: 0.5rem; }
.card p { color: var(--muted); margin-bottom: 1rem; font-size: 0.95rem; }
.btn { background: var(--accent); color: #0b0f19; border: none; font-weight: 600; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; }
.btn:hover { background: var(--accent-hover); color: #fff; }
pre { background: var(--code-bg); border: 1px solid var(--border); border-radius: 6px; padding: 0.75rem; font-family: monospace; font-size: 0.85rem; color: #38bdf8; margin-top: 0.75rem; overflow-x: auto; }
footer { text-align: center; color: var(--muted); font-size: 0.85rem; margin-top: 2rem; }
`

const templateWasmerToml = `[package]
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

const templateAppYaml = `---
name: %s
package: .
capabilities:
  insecure_allow_all_network: true
`

const templateGitignore = `bin/
*.wasm
.DS_Store
`
