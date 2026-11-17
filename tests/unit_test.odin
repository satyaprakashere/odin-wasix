#+build wasm32
package tests

import "core:fmt"
import "core:os"
import wasi "core:sys/wasm/wasi"

import "wasix:sys"
import "wasix:net"
import "wasix:http"

total_tests := 0
passed_tests := 0

assert_true :: proc(condition: bool, test_name: string) {
	total_tests += 1
	if condition {
		passed_tests += 1
		fmt.printfln("  ✓ PASS: %s", test_name)
	} else {
		fmt.printfln("  ✗ FAIL: %s", test_name)
	}
}

main :: proc() {
	fmt.println("==================================================")
	fmt.println("🧪 Running WASIX Unit & Subsystem Tests")
	fmt.println("==================================================")

	// -------------------------------------------------------------------------
	// 1. WASIX Kernel & System Tests (wasix:sys)
	// -------------------------------------------------------------------------
	fmt.println("\n[1] wasix:sys System Calls")

	pid: sys.pid_t
	err_pid := sys.proc_id(&pid)
	assert_true(err_pid == .SUCCESS && pid > 0, fmt.tprintf("proc_id returned PID %d", pid))

	parallelism: uint
	err_threads := sys.thread_parallelism(&parallelism)
	assert_true(err_threads == .SUCCESS && parallelism >= 1, fmt.tprintf("thread_parallelism returned %d cores", parallelism))

	cwd_buf: [256]u8
	cwd_len: wasi.size_t = len(cwd_buf)
	err_cwd := sys.getcwd(&cwd_buf[0], &cwd_len)
	assert_true(err_cwd == .SUCCESS && cwd_len > 0, fmt.tprintf("getcwd succeeded (path: %s)", string(cwd_buf[:cwd_len])))

	pipe_read, pipe_write: wasi.fd_t
	err_pipe := sys.fd_pipe(&pipe_read, &pipe_write)
	assert_true(err_pipe == .SUCCESS && pipe_read != pipe_write, fmt.tprintf("fd_pipe allocated (read=%d, write=%d)", pipe_read, pipe_write))
	if err_pipe == .SUCCESS {
		wasi.fd_close(pipe_read)
		wasi.fd_close(pipe_write)
	}

	// -------------------------------------------------------------------------
	// 2. WASIX Networking & Endpoints (wasix:net)
	// -------------------------------------------------------------------------
	fmt.println("\n[2] wasix:net Endpoints & Sockets")

	ip, ok_ip := net.parse_ipv4("127.0.0.1")
	assert_true(ok_ip && ip == net.IP4_Address([4]u8{127, 0, 0, 1}), "parse_ipv4('127.0.0.1')")

	ip2, ok_ip2 := net.parse_ipv4("192.168.1.50")
	assert_true(ok_ip2 && ip2 == net.IP4_Address([4]u8{192, 168, 1, 50}), "parse_ipv4('192.168.1.50')")

	_, ok_fail := net.parse_ipv4("999.0.0.1")
	assert_true(!ok_fail, "parse_ipv4('999.0.0.1') correctly rejected")

	ep := net.Endpoint{
		address = net.IP4_Address([4]u8{127, 0, 0, 1}),
		port = 8080,
	}
	ep_str := net.endpoint_to_string(ep, context.temp_allocator)
	assert_true(ep_str == "127.0.0.1:8080", fmt.tprintf("endpoint_to_string: %s", ep_str))

	// Socket listen test
	listener, err_listen := net.listen_tcp_str("0.0.0.0", 8199)
	assert_true(err_listen == .SUCCESS && listener.fd > 0, "listen_tcp_str('0.0.0.0', 8199)")
	if err_listen == .SUCCESS {
		net.close_listener(&listener)
		assert_true(listener.fd == 0, "close_listener reset fd")
	}

	// -------------------------------------------------------------------------
	// 3. HTTP Parser & Routing (wasix:http)
	// -------------------------------------------------------------------------
	fmt.println("\n[3] wasix:http Parser & Router")

	m_get, ok_mget := http.parse_method("GET")
	assert_true(ok_mget && m_get == .GET, "parse_method('GET')")

	m_post, ok_mpost := http.parse_method("POST")
	assert_true(ok_mpost && m_post == .POST, "parse_method('POST')")

	raw_http := "POST /api/v1/echo?foo=bar HTTP/1.1\r\nHost: localhost:8080\r\nContent-Type: application/json\r\nContent-Length: 13\r\n\r\n{\"key\":\"val\"}"
	dummy_conn: net.TCP_Conn
	req, ok_req := http.parse_request(transmute([]u8)raw_http, &dummy_conn, context.temp_allocator)
	assert_true(ok_req, "parse_request returned ok")
	assert_true(req.method == .POST, "request method is POST")
	assert_true(req.path == "/api/v1/echo", fmt.tprintf("request path: %s", req.path))
	assert_true(req.query == "foo=bar", fmt.tprintf("request query: %s", req.query))

	ct, has_ct := http.request_get_header(&req, "Content-Type")
	assert_true(has_ct && ct == "application/json", fmt.tprintf("header Content-Type: %s", ct))
	assert_true(string(req.body) == "{\"key\":\"val\"}", fmt.tprintf("request body: %s", string(req.body)))

	// MIME type lookup
	assert_true(http.mime_type_from_path("index.html") == "text/html; charset=utf-8", "mime_type_from_path('index.html')")
	assert_true(http.mime_type_from_path("style.css") == "text/css; charset=utf-8", "mime_type_from_path('style.css')")
	assert_true(http.mime_type_from_path("binary.wasm") == "application/wasm", "mime_type_from_path('binary.wasm')")
	assert_true(http.mime_type_from_path("data.json") == "application/json; charset=utf-8", "mime_type_from_path('data.json')")
	assert_true(http.mime_type_from_path("manifest.webmanifest") == "application/manifest+json; charset=utf-8", "mime_type_from_path('manifest.webmanifest')")
	assert_true(http.request_query(&req, "foo") == "bar", "request_query('foo') == 'bar'")

	// Router dispatch & parameterized matching
	router: http.Router
	http.router_init(&router)
	defer http.router_destroy(&router)

	param_captured := ""
	http.get(&router, "/api/users/:id", proc(req: ^http.Request, res: ^http.Response) {
		res.status = .OK
	})

	dispatch_req: http.Request
	dispatch_req.method = .GET
	dispatch_req.path = "/api/users/42"
	dispatch_req.params = make([dynamic]http.Param, context.temp_allocator)

	dispatch_res: http.Response
	dispatch_res.status = .Not_Found
	dispatch_res.headers = make([dynamic]http.Header, context.temp_allocator)
	dispatch_res.body = make([dynamic]u8, context.temp_allocator)

	http.dispatch(&router, &dispatch_req, &dispatch_res)
	assert_true(dispatch_res.status == .OK, "router parameterized route dispatch returns 200 OK")
	assert_true(http.request_param(&dispatch_req, "id") == "42", "router captured param 'id' == '42'")

	// -------------------------------------------------------------------------
	// Summary
	// -------------------------------------------------------------------------
	fmt.println("\n==================================================")
	fmt.printfln("Results: %d/%d PASSED (%.1f%%)", passed_tests, total_tests, f64(passed_tests) * 100.0 / f64(total_tests))
	fmt.println("==================================================")

	if passed_tests != total_tests {
		os.exit(1)
	}
}
