#+build wasm32
package sys

import wasi "core:sys/wasm/wasi"

foreign import wasix "wasix_32v1"

@(default_calling_convention="contextless")
foreign wasix {
	// Socket operations
	sock_open         :: proc(af: Address_Family, socktype: Sock_Type, sock_proto: Sock_Proto, ro_fd: ^wasi.fd_t) -> wasi.errno_t ---
	sock_pair         :: proc(af: Address_Family, socktype: Sock_Type, sock_proto: Sock_Proto, ro_fd1: ^wasi.fd_t, ro_fd2: ^wasi.fd_t) -> wasi.errno_t ---
	sock_bind         :: proc(fd: wasi.fd_t, addr: rawptr) -> wasi.errno_t ---
	sock_listen       :: proc(fd: wasi.fd_t, backlog: wasi.size_t) -> wasi.errno_t ---
	sock_accept_v2    :: proc(fd: wasi.fd_t, flags: wasi.fdflags_t, ro_fd: ^wasi.fd_t, ro_addr: rawptr) -> wasi.errno_t ---
	sock_connect      :: proc(fd: wasi.fd_t, addr: rawptr) -> wasi.errno_t ---
	sock_addr_local   :: proc(fd: wasi.fd_t, ro_addr: rawptr) -> wasi.errno_t ---
	sock_addr_peer    :: proc(fd: wasi.fd_t, ro_addr: rawptr) -> wasi.errno_t ---
	sock_status       :: proc(fd: wasi.fd_t, ro_status: ^u8) -> wasi.errno_t ---
	sock_set_opt_flag :: proc(fd: wasi.fd_t, opt: Sock_Option, val: bool) -> wasi.errno_t ---
	sock_get_opt_flag :: proc(fd: wasi.fd_t, opt: Sock_Option, ro_val: ^bool) -> wasi.errno_t ---
	sock_set_opt_time :: proc(fd: wasi.fd_t, opt: Sock_Option, timeout_ns: ^u64) -> wasi.errno_t ---
	sock_get_opt_time :: proc(fd: wasi.fd_t, opt: Sock_Option, ro_timeout_ns: ^u64) -> wasi.errno_t ---
	sock_set_opt_size :: proc(fd: wasi.fd_t, opt: Sock_Option, size: u64) -> wasi.errno_t ---
	sock_get_opt_size :: proc(fd: wasi.fd_t, opt: Sock_Option, ro_size: ^u64) -> wasi.errno_t ---

	// Threading & Futex primitives
	thread_id          :: proc(ro_tid: ^tid_t) -> wasi.errno_t ---
	thread_parallelism :: proc(ro_parallelism: ^uint) -> wasi.errno_t ---
	thread_sleep       :: proc(duration_ns: u64) -> wasi.errno_t ---
	thread_join        :: proc(tid: tid_t) -> wasi.errno_t ---
	futex_wait         :: proc(futex: ^u32, expected: u32, timeout_ns: ^u64) -> wasi.errno_t ---
	futex_wake         :: proc(futex: ^u32, ro_woken: ^bool) -> wasi.errno_t ---
	futex_wake_all     :: proc(futex: ^u32, ro_woken: ^bool) -> wasi.errno_t ---

	// Process & OS primitives
	proc_id     :: proc(ro_pid: ^pid_t) -> wasi.errno_t ---
	proc_parent :: proc(ro_ppid: ^pid_t) -> wasi.errno_t ---
	proc_signal :: proc(pid: pid_t, sig: Signal) -> wasi.errno_t ---
	chdir       :: proc(path: [^]u8, path_len: wasi.size_t) -> wasi.errno_t ---
	getcwd      :: proc(buf: [^]u8, ro_buf_len: ^wasi.size_t) -> wasi.errno_t ---
	fd_pipe     :: proc(ro_fd1: ^wasi.fd_t, ro_fd2: ^wasi.fd_t) -> wasi.errno_t ---
	fd_dup      :: proc(fd: wasi.fd_t, ro_fd: ^wasi.fd_t) -> wasi.errno_t ---
	fd_dup2     :: proc(fd: wasi.fd_t, new_fd: wasi.fd_t) -> wasi.errno_t ---
}
