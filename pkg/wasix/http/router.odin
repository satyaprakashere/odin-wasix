#+build wasm32
package http

import "core:fmt"
import "core:os"
import "core:strings"

import "../net"

Handler :: proc(req: ^Request, res: ^Response)

Route :: struct {
	method:  Method,
	path:    string,
	handler: Handler,
}

Static_Mount :: struct {
	prefix: string,
	dir:    string,
}

Router :: struct {
	routes:        [dynamic]Route,
	static_mounts: [dynamic]Static_Mount,
	not_found:     Handler,
}

router_init :: proc(r: ^Router, allocator := context.allocator) {
	r.routes = make([dynamic]Route, allocator)
	r.static_mounts = make([dynamic]Static_Mount, allocator)
	r.not_found = default_not_found
}

router_destroy :: proc(r: ^Router) {
	delete(r.routes)
	delete(r.static_mounts)
}

default_not_found :: proc(req: ^Request, res: ^Response) {
	response_text(res, "404 Not Found", .Not_Found)
}

route_add :: proc(r: ^Router, method: Method, path: string, handler: Handler) {
	append(&r.routes, Route{
		method  = method,
		path    = path,
		handler = handler,
	})
}

get :: proc(r: ^Router, path: string, handler: Handler) {
	route_add(r, .GET, path, handler)
}

post :: proc(r: ^Router, path: string, handler: Handler) {
	route_add(r, .POST, path, handler)
}

put :: proc(r: ^Router, path: string, handler: Handler) {
	route_add(r, .PUT, path, handler)
}

delete_route :: proc(r: ^Router, path: string, handler: Handler) {
	route_add(r, .DELETE, path, handler)
}

serve_static :: proc(r: ^Router, prefix: string, dir: string) {
	append(&r.static_mounts, Static_Mount{
		prefix = prefix,
		dir    = dir,
	})
}

mime_type_from_path :: proc(path: string) -> string {
	if strings.has_suffix(path, ".html") || strings.has_suffix(path, ".htm") do return "text/html; charset=utf-8"
	if strings.has_suffix(path, ".css")                                     do return "text/css; charset=utf-8"
	if strings.has_suffix(path, ".js")                                      do return "application/javascript; charset=utf-8"
	if strings.has_suffix(path, ".json")                                    do return "application/json; charset=utf-8"
	if strings.has_suffix(path, ".svg")                                     do return "image/svg+xml"
	if strings.has_suffix(path, ".png")                                     do return "image/png"
	if strings.has_suffix(path, ".jpg") || strings.has_suffix(path, ".jpeg") do return "image/jpeg"
	if strings.has_suffix(path, ".ico")                                     do return "image/x-icon"
	if strings.has_suffix(path, ".txt")                                     do return "text/plain; charset=utf-8"
	if strings.has_suffix(path, ".wasm")                                    do return "application/wasm"
	return "application/octet-stream"
}

dispatch :: proc(r: ^Router, req: ^Request, res: ^Response) {
	// 1. Check exact routes
	for route in r.routes {
		if route.method == req.method && route.path == req.path {
			route.handler(req, res)
			return
		}
	}

	// 2. Check static file mounts
	if req.method == .GET || req.method == .HEAD {
		for mount in r.static_mounts {
			if strings.has_prefix(req.path, mount.prefix) {
				rel_path := req.path[len(mount.prefix):]
				if len(rel_path) == 0 || rel_path == "/" {
					rel_path = "index.html"
				}
				if strings.has_prefix(rel_path, "/") {
					rel_path = rel_path[1:]
				}

				full_file_path := fmt.tprintf("%s/%s", mount.dir, rel_path)
				data, err := os.read_entire_file(full_file_path, context.temp_allocator)
				if err == nil {
					res.status = .OK
					response_set_header(res, "Content-Type", mime_type_from_path(full_file_path))
					clear(&res.body)
					append(&res.body, ..data)
					return
				}
			}
		}
	}

	// 3. Fallback to Not Found
	r.not_found(req, res)
}
