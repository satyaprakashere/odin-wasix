#+build wasm32
package sys

import wasi "core:sys/wasm/wasi"

// Address Family in WASIX
Address_Family :: enum u8 {
	Unspec = 0,
	Inet4  = 1,
	Inet6  = 2,
	Unix   = 3,
}

// Socket types
Sock_Type :: enum u8 {
	Unused    = 0,
	Stream    = 1,
	Dgram     = 2,
	Raw       = 3,
	SeqPacket = 4,
}

// Socket protocols
Sock_Proto :: enum u16 {
	Ip        = 0,
	Icmp      = 1,
	Igmp      = 2,
	Tcp       = 6,
	Udp       = 17,
	Ipv6      = 41,
	Ipv6Route = 43,
	Ipv6Frag  = 44,
	Ipv6Icmp  = 58,
	Ipv6Nonxt = 59,
	Ipv6Opts  = 60,
}

// Socket options
Sock_Option :: enum u8 {
	No_Push                = 0,
	No_Delay               = 1,
	Reuse_Address          = 2,
	Reuse_Port             = 3,
	Send_Timeout           = 4,
	Recv_Timeout           = 5,
	Send_Buf_Size          = 6,
	Recv_Buf_Size          = 7,
	Ttl                    = 8,
	Multicast_Ttl_V4       = 9,
	Multicast_Loop_V4      = 10,
	Multicast_Ttl_V6       = 11,
	Multicast_Loop_V6      = 12,
	Keep_Alive             = 13,
	Broadcast              = 14,
	Send_Lowat             = 15,
	Recv_Lowat             = 16,
	Oob_Inline             = 17,
	Linger                 = 18,
	Error                  = 19,
	Accept_Conn            = 20,
}

// IPv4 Address representation (4 octets)
Addr_Ip4 :: struct {
	n0, n1, h0, h1: u8,
}

// IPv6 Address representation (16 bytes)
Addr_Ip6 :: struct {
	octets: [16]u8,
}

// Low-level WASIX IPv4 + Port socket address layout
// Note: In WASIX, port is stored as little-endian u16 (native WASM memory layout)
Addr_Ip4_Port :: struct #packed {
	tag:  Address_Family,
	pad:  u8,
	port: u16,
	ip:   [4]u8,
}

// Low-level WASIX IPv6 + Port socket address layout
Addr_Ip6_Port :: struct #packed {
	tag:  Address_Family,
	pad:  u8,
	port: u16,
	ip:   [16]u8,
}

// Generic union address buffer
Addr_Port :: struct #packed {
	tag:  Address_Family,
	pad:  u8,
	port: u16,
	data: [28]u8,
}

// Process ID type
pid_t :: distinct u32

// Thread ID type
tid_t :: distinct u32

// Process signal enum
Signal :: enum u8 {
	None   = 0,
	Hup    = 1,
	Int    = 2,
	Quit   = 3,
	Ill    = 4,
	Trap   = 5,
	Abrt   = 6,
	Bus    = 7,
	Fpe    = 8,
	Kill   = 9,
	Usr1   = 10,
	Segv   = 11,
	Usr2   = 12,
	Pipe   = 13,
	Alrm   = 14,
	Term   = 15,
	Chld   = 17,
	Cont   = 18,
	Stop   = 19,
	Tstp   = 20,
	Ttin   = 21,
	Ttou   = 22,
	Urg    = 23,
	Xcpu   = 24,
	Xfsz   = 25,
	Vtalrm = 26,
	Prof   = 27,
	Winch  = 28,
	Poll   = 29,
	Pwr    = 30,
	Sys    = 31,
}
