#+build wasm32
package http

import "core:strconv"
import "core:strings"

import "../net"

parse_method :: proc(m: string) -> (Method, bool) {
	switch m {
	case "GET":     return .GET, true
	case "POST":    return .POST, true
	case "PUT":     return .PUT, true
	case "DELETE":  return .DELETE, true
	case "PATCH":   return .PATCH, true
	case "HEAD":    return .HEAD, true
	case "OPTIONS": return .OPTIONS, true
	}
	return .GET, false
}

parse_request :: proc(raw_data: []u8, conn: ^net.TCP_Conn, allocator := context.allocator) -> (req: Request, ok: bool) {
	req.conn = conn
	req.headers = make([dynamic]Header, allocator)

	str := string(raw_data)
	header_end := strings.index(str, "\r\n\r\n")
	if header_end == -1 {
		header_end = strings.index(str, "\n\n")
		if header_end == -1 do return req, false
	}

	header_section := str[:header_end]
	body_start := header_end + 4
	if strings.contains(str[header_end:header_end+4], "\n\n") && !strings.contains(str[header_end:header_end+4], "\r\n\r\n") {
		body_start = header_end + 2
	}

	if body_start <= len(raw_data) {
		req.body = raw_data[body_start:]
	}

	lines := strings.split(header_section, "\n", context.temp_allocator)
	if len(lines) == 0 do return req, false

	// Parse Request Line (e.g., "GET /api/v1/health?token=abc HTTP/1.1")
	first_line := strings.trim_right_space(lines[0])
	parts := strings.split(first_line, " ", context.temp_allocator)
	if len(parts) < 2 do return req, false

	method, method_ok := parse_method(parts[0])
	if !method_ok do return req, false
	req.method = method

	req.raw_url = parts[1]
	if q_idx := strings.index(req.raw_url, "?"); q_idx != -1 {
		req.path = req.raw_url[:q_idx]
		req.query = req.raw_url[q_idx+1:]
	} else {
		req.path = req.raw_url
		req.query = ""
	}

	// Parse Headers
	for i in 1..<len(lines) {
		line := strings.trim_space(lines[i])
		if len(line) == 0 do continue

		colon_idx := strings.index(line, ":")
		if colon_idx == -1 do continue

		key := strings.trim_space(line[:colon_idx])
		val := strings.trim_space(line[colon_idx+1:])
		append(&req.headers, Header{key = key, value = val})
	}

	return req, true
}

destroy_request :: proc(req: ^Request) {
	delete(req.headers)
}
