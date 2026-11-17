package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"

import "../../pkg/wasix/http"
import "../../pkg/wasix/sys"

start_time: time.Time

main :: proc() {
	start_time = time.now()

	port: u16 = 8080
	if port_env, found := os.lookup_env("PORT"); found {
		if p, ok := strconv.parse_int(port_env); ok && p > 0 && p <= 65535 {
			port = u16(p)
		}
	}

	host := "0.0.0.0"

	server: http.Server
	http.server_init(&server)
	defer http.server_destroy(&server)

	// Static file serving
	http.serve_static(&server.router, "/public", "public")

	// Root landing route
	http.get(&server.router, "/", proc(req: ^http.Request, res: ^http.Response) {
		// Try reading public/index.html first
		if html_data, ok := os.read_entire_file("public/index.html", context.temp_allocator); ok {
			http.response_html(res, string(html_data))
			return
		}

		// Fallback embedded dashboard
		fallback_html := `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Odin WASIX Webserver</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; padding: 2rem; max-width: 800px; margin: auto; }
    h1 { color: #38bdf8; }
    .card { background: #1e293b; padding: 1.5rem; border-radius: 8px; border: 1px solid #334155; margin-top: 1rem; }
    code { background: #020617; padding: 0.2rem 0.4rem; border-radius: 4px; color: #a5f3fc; }
    a { color: #38bdf8; text-decoration: none; }
    .badge { display: inline-block; background: #0284c7; color: white; padding: 0.2rem 0.6rem; border-radius: 9999px; font-size: 0.8rem; font-weight: bold; }
  </style>
</head>
<body>
  <span class="badge">Wasmer Edge Ready</span>
  <h1>⚡ Odin Web Server on WASIX</h1>
  <p>Replacing Rust webservers with an ultra-lightweight, zero-overhead Odin binary.</p>
  <div class="card">
    <h3>Available Endpoints</h3>
    <ul>
      <li><a href="/api/v1/health"><code>GET /api/v1/health</code></a> - Health probe</li>
      <li><a href="/api/v1/system"><code>GET /api/v1/system</code></a> - WASIX runtime diagnostics (PID, Parallelism)</li>
      <li><code>POST /api/v1/echo</code> - Request echoing</li>
    </ul>
  </div>
</body>
</html>`
		http.response_html(res, fallback_html)
	})

	// Health check endpoint
	http.get(&server.router, "/api/v1/health", proc(req: ^http.Request, res: ^http.Response) {
		elapsed := time.since(start_time)
		json_payload := fmt.tprintf(`{"status":"healthy","uptime_seconds":%.3f}`, time.duration_seconds(elapsed))
		http.response_json(res, json_payload)
	})

	// System diagnostics endpoint querying WASIX
	http.get(&server.router, "/api/v1/system", proc(req: ^http.Request, res: ^http.Response) {
		pid: sys.pid_t
		sys.proc_id(&pid)

		parallelism: uint
		sys.thread_parallelism(&parallelism)

		json_payload := fmt.tprintf(`{"runtime":"wasix_32v1","language":"odin","pid":%d,"hardware_threads":%d,"memory_model":"wasm32"}`, pid, parallelism)
		http.response_json(res, json_payload)
	})

	// Echo POST endpoint
	http.post(&server.router, "/api/v1/echo", proc(req: ^http.Request, res: ^http.Response) {
		body_str := string(req.body)
		if len(body_str) == 0 {
			body_str = "{}"
		}
		json_payload := fmt.tprintf(`{"echo":%s}`, body_str)
		http.response_json(res, json_payload)
	})

	fmt.printfln("[INIT] Starting Odin server on %s:%d ...", host, port)
	http.server_listen_and_serve(&server, host, port)
}
