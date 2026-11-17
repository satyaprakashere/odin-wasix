#+build wasm32
package http

import "core:fmt"
import "core:strings"

import "../net"

Method :: enum {
	GET,
	POST,
	PUT,
	DELETE,
	PATCH,
	HEAD,
	OPTIONS,
}

Status :: enum int {
	OK                    = 200,
	Created               = 201,
	Accepted              = 202,
	No_Content            = 204,
	Moved_Permanently     = 301,
	Found                 = 302,
	Not_Modified          = 304,
	Bad_Request           = 400,
	Unauthorized          = 401,
	Forbidden             = 403,
	Not_Found             = 404,
	Method_Not_Allowed    = 405,
	Internal_Server_Error = 500,
	Not_Implemented       = 501,
	Bad_Gateway           = 502,
	Service_Unavailable   = 503,
}

status_to_string :: proc(status: Status) -> string {
	switch status {
	case .OK:                    return "200 OK"
	case .Created:               return "201 Created"
	case .Accepted:              return "202 Accepted"
	case .No_Content:            return "204 No Content"
	case .Moved_Permanently:     return "301 Moved Permanently"
	case .Found:                 return "302 Found"
	case .Not_Modified:          return "304 Not Modified"
	case .Bad_Request:           return "400 Bad Request"
	case .Unauthorized:          return "401 Unauthorized"
	case .Forbidden:             return "403 Forbidden"
	case .Not_Found:             return "404 Not Found"
	case .Method_Not_Allowed:    return "405 Method Not Allowed"
	case .Internal_Server_Error: return "500 Internal Server Error"
	case .Not_Implemented:       return "501 Not Implemented"
	case .Bad_Gateway:           return "502 Bad Gateway"
	case .Service_Unavailable:   return "503 Service Unavailable"
	}
	return "200 OK"
}

Header :: struct {
	key:   string,
	value: string,
}

Request :: struct {
	method:   Method,
	path:     string,
	raw_url:  string,
	query:    string,
	headers:  [dynamic]Header,
	body:     []u8,
	conn:     ^net.TCP_Conn,
}

Response :: struct {
	status:  Status,
	headers: [dynamic]Header,
	body:    [dynamic]u8,
	written: bool,
}

request_get_header :: proc(req: ^Request, key: string) -> (value: string, found: bool) {
	for h in req.headers {
		if strings.equal_fold(h.key, key) {
			return h.value, true
		}
	}
	return "", false
}

response_set_header :: proc(res: ^Response, key: string, value: string) {
	for &h in res.headers {
		if strings.equal_fold(h.key, key) {
			h.value = value
			return
		}
	}
	append(&res.headers, Header{key = key, value = value})
}

response_status :: proc(res: ^Response, status: Status) {
	res.status = status
}

response_text :: proc(res: ^Response, text: string, status: Status = .OK) {
	res.status = status
	response_set_header(res, "Content-Type", "text/plain; charset=utf-8")
	clear(&res.body)
	append(&res.body, ..transmute([]u8)text)
}

response_html :: proc(res: ^Response, html: string, status: Status = .OK) {
	res.status = status
	response_set_header(res, "Content-Type", "text/html; charset=utf-8")
	clear(&res.body)
	append(&res.body, ..transmute([]u8)html)
}

response_json :: proc(res: ^Response, json_str: string, status: Status = .OK) {
	res.status = status
	response_set_header(res, "Content-Type", "application/json; charset=utf-8")
	clear(&res.body)
	append(&res.body, ..transmute([]u8)json_str)
}
