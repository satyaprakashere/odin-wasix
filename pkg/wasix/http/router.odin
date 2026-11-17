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
	routes:         [dynamic]Route,
	static_mounts:  [dynamic]Static_Mount,
	not_found:      Handler,
	spa_entrypoint: string,
}

router_init :: proc(r: ^Router, allocator := context.allocator) {
	r.routes = make([dynamic]Route, allocator)
	r.static_mounts = make([dynamic]Static_Mount, allocator)
	r.not_found = default_not_found
	r.spa_entrypoint = ""
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

options :: proc(r: ^Router, path: string, handler: Handler) {
	route_add(r, .OPTIONS, path, handler)
}

serve_static :: proc(r: ^Router, prefix: string, dir: string) {
	append(&r.static_mounts, Static_Mount{
		prefix = prefix,
		dir    = dir,
	})
}

enable_spa_fallback :: proc(r: ^Router, entrypoint: string) {
	r.spa_entrypoint = entrypoint
}

mime_type_from_path :: proc(path: string) -> string {
	if strings.has_suffix(path, ".html") || strings.has_suffix(path, ".htm") do return "text/html; charset=utf-8"
	if strings.has_suffix(path, ".css")                                     do return "text/css; charset=utf-8"
	if strings.has_suffix(path, ".js") || strings.has_suffix(path, ".mjs")  do return "application/javascript; charset=utf-8"
	if strings.has_suffix(path, ".json")                                    do return "application/json; charset=utf-8"
	if strings.has_suffix(path, ".webmanifest") || strings.has_suffix(path, ".manifest") do return "application/manifest+json; charset=utf-8"
	if strings.has_suffix(path, ".svg")                                     do return "image/svg+xml"
	if strings.has_suffix(path, ".png")                                     do return "image/png"
	if strings.has_suffix(path, ".jpg") || strings.has_suffix(path, ".jpeg") do return "image/jpeg"
	if strings.has_suffix(path, ".gif")                                     do return "image/gif"
	if strings.has_suffix(path, ".webp")                                    do return "image/webp"
	if strings.has_suffix(path, ".ico")                                     do return "image/x-icon"
	if strings.has_suffix(path, ".txt")                                     do return "text/plain; charset=utf-8"
	if strings.has_suffix(path, ".wasm")                                    do return "application/wasm"
	if strings.has_suffix(path, ".woff2")                                   do return "font/woff2"
	if strings.has_suffix(path, ".woff")                                    do return "font/woff"
	if strings.has_suffix(path, ".ttf")                                     do return "font/ttf"
	if strings.has_suffix(path, ".otf")                                     do return "font/otf"
	if strings.has_suffix(path, ".mp3")                                     do return "audio/mpeg"
	if strings.has_suffix(path, ".mp4")                                     do return "video/mp4"
	if strings.has_suffix(path, ".webm")                                    do return "video/webm"
	return "application/octet-stream"
}

match_route_segments :: proc(pattern: string, path: string, params: ^[dynamic]Param) -> bool {
	if pattern == path do return true
	if !strings.contains(pattern, ":") && !strings.contains(pattern, "*") do return false

	p_segs := strings.split(pattern, "/", context.temp_allocator)
	r_segs := strings.split(path, "/", context.temp_allocator)

	if !strings.contains(pattern, "*") && len(p_segs) != len(r_segs) {
		return false
	}

	for i in 0..<len(p_segs) {
		p_seg := p_segs[i]
		if strings.has_prefix(p_seg, "*") {
			return true
		}
		if i >= len(r_segs) do return false
		r_seg := r_segs[i]

		if strings.has_prefix(p_seg, ":") {
			param_key := p_seg[1:]
			append(params, Param{key = param_key, value = r_seg})
		} else if p_seg != r_seg {
			return false
		}
	}

	return len(p_segs) == len(r_segs)
}

dispatch :: proc(r: ^Router, req: ^Request, res: ^Response) {
	// 1. Check registered routes (exact match or parameter pattern match)
	for route in r.routes {
		if route.method == req.method {
			if route.path == req.path {
				route.handler(req, res)
				return
			}

			clear(&req.params)
			if match_route_segments(route.path, req.path, &req.params) {
				route.handler(req, res)
				return
			}
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

	// 3. Fallback to SPA entrypoint if configured and navigation request
	if (req.method == .GET || req.method == .HEAD) && len(r.spa_entrypoint) > 0 {
		// Only fallback if not requesting a missing static file with an extension
		has_ext := false
		if last_dot := strings.last_index(req.path, "."); last_dot != -1 {
			if last_slash := strings.last_index(req.path, "/"); last_dot > last_slash {
				has_ext = true
			}
		}

		if !has_ext {
			if data, err := os.read_entire_file(r.spa_entrypoint, context.temp_allocator); err == nil {
				res.status = .OK
				response_set_header(res, "Content-Type", "text/html; charset=utf-8")
				clear(&res.body)
				append(&res.body, ..data)
				return
			}
		}
	}

	// 4. Fallback to Not Found
	r.not_found(req, res)
}
