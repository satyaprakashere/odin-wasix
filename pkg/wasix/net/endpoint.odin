#+build wasm32
package net

import "core:fmt"
import "core:strconv"
import "core:strings"

import sys "../sys"

IP4_Address :: distinct [4]u8
IP6_Address :: distinct [16]u8

IP_Address :: union {
	IP4_Address,
	IP6_Address,
}

Endpoint :: struct {
	address: IP_Address,
	port:    u16,
}

endpoint_to_raw :: proc(ep: Endpoint) -> sys.Addr_Port {
	raw: sys.Addr_Port
	raw.port = ep.port

	switch addr in ep.address {
	case IP4_Address:
		raw.tag = .Inet4
		raw.pad = 0
		raw.data[0] = addr[0]
		raw.data[1] = addr[1]
		raw.data[2] = addr[2]
		raw.data[3] = addr[3]
	case IP6_Address:
		raw.tag = .Inet6
		raw.pad = 0
		for i in 0..<16 {
			raw.data[i] = addr[i]
		}
	}
	return raw
}

raw_to_endpoint :: proc(raw: ^sys.Addr_Port) -> (ep: Endpoint) {
	ep.port = raw.port
	switch raw.tag {
	case .Inet4:
		ip4: IP4_Address
		ip4[0] = raw.data[0]
		ip4[1] = raw.data[1]
		ip4[2] = raw.data[2]
		ip4[3] = raw.data[3]
		ep.address = ip4
	case .Inet6:
		ip6: IP6_Address
		for i in 0..<16 {
			ip6[i] = raw.data[i]
		}
		ep.address = ip6
	case .Unspec, .Unix:
		ip4: IP4_Address
		ep.address = ip4
	}
	return
}

endpoint_to_string :: proc(ep: Endpoint, allocator := context.allocator) -> string {
	switch addr in ep.address {
	case IP4_Address:
		return fmt.aprintf("%d.%d.%d.%d:%d", addr[0], addr[1], addr[2], addr[3], ep.port, allocator = allocator)
	case IP6_Address:
		return fmt.aprintf("[%x:%x:%x:%x:%x:%x:%x:%x]:%d",
			u16(addr[0])<<8 | u16(addr[1]),
			u16(addr[2])<<8 | u16(addr[3]),
			u16(addr[4])<<8 | u16(addr[5]),
			u16(addr[6])<<8 | u16(addr[7]),
			u16(addr[8])<<8 | u16(addr[9]),
			u16(addr[10])<<8 | u16(addr[11]),
			u16(addr[12])<<8 | u16(addr[13]),
			u16(addr[14])<<8 | u16(addr[15]),
			ep.port,
			allocator = allocator,
		)
	}
	return ""
}

parse_ipv4 :: proc(s: string) -> (ip: IP4_Address, ok: bool) {
	parts := strings.split(s, ".", context.temp_allocator)
	if len(parts) != 4 do return ip, false

	for i in 0..<4 {
		val := strconv.parse_int(parts[i]) or_return
		if val < 0 || val > 255 do return ip, false
		ip[i] = u8(val)
	}
	return ip, true
}
