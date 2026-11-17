#+build wasm32
package net

import wasi "core:sys/wasm/wasi"

import sys "../sys"

TCP_Listener :: struct {
	fd:       wasi.fd_t,
	endpoint: Endpoint,
}

TCP_Conn :: struct {
	fd:              wasi.fd_t,
	local_endpoint:  Endpoint,
	remote_endpoint: Endpoint,
}

listen_tcp :: proc(ep: Endpoint, backlog: uint = 128) -> (listener: TCP_Listener, err: wasi.errno_t) {
	fd: wasi.fd_t
	err = sys.sock_open(.Inet4, .Stream, .Tcp, &fd)
	if err != .SUCCESS do return

	// Enable SO_REUSEADDR
	sys.sock_set_opt_flag(fd, .Reuse_Address, true)

	raw_addr := endpoint_to_raw(ep)
	err = sys.sock_bind(fd, &raw_addr)
	if err != .SUCCESS {
		wasi.fd_close(fd)
		return
	}

	err = sys.sock_listen(fd, wasi.size_t(backlog))
	if err != .SUCCESS {
		wasi.fd_close(fd)
		return
	}

	listener.fd = fd
	listener.endpoint = ep
	return listener, .SUCCESS
}

listen_tcp_str :: proc(addr_str: string, port: u16, backlog: uint = 128) -> (listener: TCP_Listener, err: wasi.errno_t) {
	ip, ok := parse_ipv4(addr_str)
	if !ok {
		return listener, .INVAL
	}
	ep := Endpoint{
		address = ip,
		port = port,
	}
	return listen_tcp(ep, backlog)
}

accept_tcp :: proc(listener: ^TCP_Listener) -> (conn: TCP_Conn, err: wasi.errno_t) {
	client_fd: wasi.fd_t
	raw_peer: sys.Addr_Port

	err = sys.sock_accept_v2(listener.fd, {}, &client_fd, &raw_peer)
	if err != .SUCCESS do return

	conn.fd = client_fd
	conn.local_endpoint = listener.endpoint
	conn.remote_endpoint = raw_to_endpoint(&raw_peer)
	return conn, .SUCCESS
}

dial_tcp :: proc(ep: Endpoint) -> (conn: TCP_Conn, err: wasi.errno_t) {
	fd: wasi.fd_t
	err = sys.sock_open(.Inet4, .Stream, .Tcp, &fd)
	if err != .SUCCESS do return

	raw_addr := endpoint_to_raw(ep)
	err = sys.sock_connect(fd, &raw_addr)
	if err != .SUCCESS {
		wasi.fd_close(fd)
		return
	}

	conn.fd = fd
	conn.remote_endpoint = ep

	raw_local: sys.Addr_Port
	if sys.sock_addr_local(fd, &raw_local) == .SUCCESS {
		conn.local_endpoint = raw_to_endpoint(&raw_local)
	}

	return conn, .SUCCESS
}

read :: proc(conn: ^TCP_Conn, buf: []u8) -> (n: int, err: wasi.errno_t) {
	bytes_read, _, e := wasi.sock_recv(conn.fd, { buf }, {})
	return int(bytes_read), e
}

write :: proc(conn: ^TCP_Conn, data: []u8) -> (n: int, err: wasi.errno_t) {
	bytes_written, e := wasi.sock_send(conn.fd, { data }, {})
	return int(bytes_written), e
}

write_string :: proc(conn: ^TCP_Conn, s: string) -> (n: int, err: wasi.errno_t) {
	return write(conn, transmute([]u8)s)
}

close :: proc(conn: ^TCP_Conn) {
	if conn.fd != 0 {
		wasi.fd_close(conn.fd)
		conn.fd = 0
	}
}

close_listener :: proc(listener: ^TCP_Listener) {
	if listener.fd != 0 {
		wasi.fd_close(listener.fd)
		listener.fd = 0
	}
}
