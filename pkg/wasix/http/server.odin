#+build wasm32
package http

import "core:fmt"
import "core:strings"

import "../net"

Server :: struct {
	router:   Router,
	listener: net.TCP_Listener,
	running:  bool,
}

server_init :: proc(s: ^Server) {
	router_init(&s.router)
	s.running = false
}

server_destroy :: proc(s: ^Server) {
	router_destroy(&s.router)
	net.close_listener(&s.listener)
}

server_listen_and_serve :: proc(s: ^Server, host: string, port: u16) -> bool {
	listener, err := net.listen_tcp_str(host, port)
	if err != .SUCCESS {
		fmt.printfln("[HTTP] Failed to bind server on %s:%d (error: %v)", host, port, err)
		return false
	}

	s.listener = listener
	s.running = true
	fmt.printfln("[HTTP] ⚡ Odin WASIX Webserver listening on http://%s:%d", host, port)

	read_buf: [8192]u8

	for s.running {
		free_all(context.temp_allocator)

		conn, accept_err := net.accept_tcp(&s.listener)
		if accept_err != .SUCCESS {
			fmt.printfln("[HTTP] Accept warning: %v", accept_err)
			continue
		}

		// Read incoming request
		nread, read_err := net.read(&conn, read_buf[:])
		if read_err != .SUCCESS || nread == 0 {
			net.close(&conn)
			continue
		}

		req, parse_ok := parse_request(read_buf[:nread], &conn, context.temp_allocator)
		if !parse_ok {
			net.close(&conn)
			continue
		}

		// Prepare response
		res := Response{
			status  = .OK,
			headers = make([dynamic]Header, context.temp_allocator),
			body    = make([dynamic]u8, context.temp_allocator),
		}

		// Set default headers
		response_set_header(&res, "Server", "Odin-WASIX/1.0")
		response_set_header(&res, "Connection", "close")

		// Route request
		dispatch(&s.router, &req, &res)

		// Set Content-Length
		response_set_header(&res, "Content-Length", fmt.tprintf("%d", len(res.body)))

		// Format and send HTTP response
		send_response(&conn, &res, req.method == .HEAD)

		// Clean up connection
		net.close(&conn)
	}

	return true
}

send_response :: proc(conn: ^net.TCP_Conn, res: ^Response, is_head: bool = false) {
	status_line := fmt.tprintf("HTTP/1.1 %s\r\n", status_to_string(res.status))
	net.write_string(conn, status_line)

	for h in res.headers {
		header_line := fmt.tprintf("%s: %s\r\n", h.key, h.value)
		net.write_string(conn, header_line)
	}

	net.write_string(conn, "\r\n")

	if !is_head && len(res.body) > 0 {
		net.write(conn, res.body[:])
	}
}
