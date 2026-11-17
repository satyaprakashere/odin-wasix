# ⚡ odin-wasix: General WASIX Compiler Driver for Odin

[![Target](https://img.shields.io/badge/target-wasix_32v1-blue.svg)](https://wasix.org/)
[![Runtime](https://img.shields.io/badge/runtime-Wasmer_/_WASIX-orange.svg)](https://wasmer.io/)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](LICENSE)
[![Zero-Dependency](https://img.shields.io/badge/dependencies-zero-brightgreen.svg)]()

**`odin-wasix`** is the general **WASIX** ([wasix.org](https://wasix.org/)) build toolchain and compiler driver for the **Odin programming language**.

Just as [**`wasixcc`**](https://github.com/wasix-org/wasixcc) provides a seamless C/C++ compiler driver for WASIX, and `cargo-wasix` does for Rust, **`odin-wasix`** wraps the Odin compiler to provide first-class, out-of-the-box compilation and execution of general Odin code targeting the 32-bit WASIX specification (`wasix_32v1`).

---

## 🌟 Why WASIX for Odin?

Standard WebAssembly System Interface (WASI Preview 1) provides basic sandboxed file and stdout/stderr access, but fundamentally lacks **POSIX sockets, network I/O, process control, and multithreading**. 

WASIX bridges this gap with backward-compatible extensions to WASI:
- **Berkeley / POSIX Sockets**: TCP listeners, socket connections, address resolution, peer info, non-blocking I/O.
- **Process & Thread Hierarchy**: Hardware thread parallelism queries, process IDs, signals, child processes.
- **High-Performance Microservices**: Build standalone network services, web servers, and distributed edge nodes in Odin without heavy container runtimes.

### Comparing WASIX Toolchains Across Languages

| Dimension | C / C++ (`wasixcc`) | Rust (`cargo-wasix`) | Odin (`odin-wasix`) |
| :--- | :--- | :--- | :--- |
| **Driver Command** | `wasixcc main.c -o app.wasm` | `cargo wasix build` | `odin-wasix build main.odin -file` |
| **Compilation Speed** | Moderate (Clang / LLVM) | Slow (Macro expansion + rustc) | **Instant** (< 2 seconds) |
| **Wasm Binary Size** | ~1 MB – 5 MB | ~3.5 MB – 12 MB (async/tokio) | **~280 KB** (Tiny footprint) |
| **Memory Model** | Manual `malloc` / `free` | Ownership + heavy async heaps | **Context Allocators & Arenas** |
| **Runtime Ergonomics** | C standard library | Deep async futures & tokio runtime | **Clean procedural code** |
| **Runtime Portability** | Any WASIX runtime | Any WASIX runtime | **Any WASIX runtime** (Wasmer, Wasmtime, etc.) |

---

## 📦 What's Included

`odin-wasix` provides both the **compiler driver CLI** and the **core WASIX packages collection** for Odin:

```
odin-wasix/
├── odin-wasix            # Standalone zero-dependency executable driver (Bash)
├── cmd/odin-wasix/       # Native Odin implementation of the CLI (odin build cmd/odin-wasix)
│   └── main.odin
├── pkg/wasix/            # First-class WASIX package collection (-collection:wasix=...)
│   ├── sys/              # Low-level WASIX (wasix_32v1) syscalls & ABI types
│   │   ├── types.odin    # Address_Family, Sock_Type, Sock_Proto, Addr_Port, Signals
│   │   └── api.odin      # Foreign imports (sock_open, sock_bind, sock_accept_v2, etc.)
│   ├── net/              # Idiomatic high-level networking layer
│   │   ├── endpoint.odin # IP4/IP6 Address types, Endpoint parsing, string formatting
│   │   └── tcp.odin      # TCP_Listener, TCP_Conn, listen_tcp, accept_tcp, dial_tcp, read/write
│   └── http/             # Lightweight HTTP 1.1 engine
│       ├── types.odin    # Request, Response, Status, Method, Header, JSON/HTML responders
│       ├── parser.odin   # Fast HTTP/1.1 request line and header parser
│       ├── router.odin   # Route registry (GET, POST, PUT, DELETE), static mounts, MIME types
│       └── server.odin   # Server event loop, connection handling, response dispatch
├── examples/
│   └── webserver/        # Complete example web server with REST endpoints and static files
│       ├── main.odin
│       ├── public/
│       └── wasmer.toml
├── install.sh            # One-liner system installer
└── README.md
```

---

## ⚡ How It Works Under the Hood

Odin natively supports emitting WebAssembly object files targeting `-target:wasi_wasm32` using LLVM's `wasm-ld`. 

`odin-wasix` automatically passes `--allow-undefined` and configures the target environment so that WASIX foreign procedures targeting the `"wasix_32v1"` ABI link directly without requiring any forks of the Odin compiler:

```odin
foreign import wasix "wasix_32v1"

@(default_calling_convention="contextless")
foreign wasix {
    sock_open      :: proc(af: Address_Family, socktype: Sock_Type, proto: Sock_Proto, ro_fd: ^wasi.fd_t) -> wasi.errno_t ---
    sock_bind      :: proc(fd: wasi.fd_t, addr: rawptr) -> wasi.errno_t ---
    sock_listen    :: proc(fd: wasi.fd_t, backlog: wasi.size_t) -> wasi.errno_t ---
    sock_accept_v2 :: proc(fd: wasi.fd_t, flags: wasi.fdflags_t, ro_fd: ^wasi.fd_t, ro_addr: rawptr) -> wasi.errno_t ---
    proc_id        :: proc(ro_pid: ^pid_t) -> wasi.errno_t ---
    thread_parallelism :: proc(ro_parallelism: ^uint) -> wasi.errno_t ---
}
```

---

## 🚀 Quickstart

### Prerequisites
- [**Odin Compiler**](https://odin-lang.org/docs/install/) (`odin` in your `PATH`)
- A WASIX-compliant runtime such as [**Wasmer**](https://wasmer.io/) (`curl https://get.wasmer.io -sSfL | sh`)

### Installation

Install `odin-wasix` with a single command:
```bash
curl -fsSL https://raw.githubusercontent.com/satyaprakashere/odin-wasix/main/install.sh | bash
```

Or clone the repository and run directly:
```bash
git clone https://github.com/satyaprakashere/odin-wasix.git
cd odin-wasix
chmod +x odin-wasix
./odin-wasix help
```

To build the native binary CLI using Odin itself:
```bash
odin build cmd/odin-wasix -out:bin/odin-wasix
./bin/odin-wasix help
```

---

## 🛠️ CLI Usage & Workflow

The `odin-wasix` CLI acts as an intelligent wrapper around `odin`, forwarding compiler flags and automatically configuring WASIX collections and linker settings.

### 1. Scaffold a New Project
```bash
odin-wasix new my-service
cd my-service
```
This generates a starter project with `main.odin` showcasing WASIX system calls and networking.

### 2. Type-Check for WASIX Target
Verify that your Odin code type-checks against the WASIX 32-bit architecture:
```bash
odin-wasix check .
# Or for a single file:
odin-wasix check main.odin -file
```

### 3. Build a WASIX Binary
Compile your Odin code to a `.wasm` binary:
```bash
# Debug build
odin-wasix build main.odin -file -out:app.wasm

# Optimized release build (size or speed)
odin-wasix build main.odin -file -out:app.wasm -o:speed
```

All standard Odin flags (`-o:speed`, `-debug`, `-show-timings`, `-collection:...`) are passed directly through to the Odin compiler.

### 4. Run with WASIX Runtime
Build and execute immediately in Wasmer (or your configured `WASIX_RUNNER`):
```bash
odin-wasix run main.odin -file
```

Pass runtime arguments to your application by separating with `--`:
```bash
odin-wasix run main.odin -file -- --port 9000 --verbose
```

### 5. Automated Test Suite
Run the end-to-end integration test suite validating real TCP sockets, HTTP endpoints, JSON parsing, and static file serving:
```bash
odin-wasix test
```

---

## 💡 Code Examples

### 1. WASIX Process & System Diagnostics
Query process IDs and available hardware thread concurrency in WASIX:

```odin
package main

import "core:fmt"
import "wasix:sys"

main :: proc() {
    pid: sys.pid_t
    sys.proc_id(&pid)

    threads: uint
    sys.thread_parallelism(&threads)

    fmt.printfln("Running in WASIX! Process ID: %d | Hardware Concurrency: %d threads", pid, threads)
}
```

### 2. Low-Level Idiomatic TCP Networking
Create a TCP listener, accept incoming connections, read from sockets, and write responses:

```odin
package main

import "core:fmt"
import "wasix:net"

main :: proc() {
    listener, err := net.listen_tcp_str("0.0.0.0", 8080)
    if err != .SUCCESS {
        fmt.printfln("Failed to listen on socket: %v", err)
        return
    }
    defer net.close_listener(&listener)

    fmt.println("TCP listener active on 0.0.0.0:8080. Waiting for connections...")

    for {
        conn, accept_err := net.accept_tcp(&listener)
        if accept_err != .SUCCESS do continue

        msg := "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, WASIX!\n"
        net.write_string(&conn, msg)
        net.close_conn(&conn)
    }
}
```

### 3. Lightweight HTTP 1.1 Microservice
Use the included `wasix:http` module for routing, REST APIs, JSON responses, and static asset streaming:

```odin
package main

import "core:fmt"
import "wasix:http"

main :: proc() {
    server: http.Server
    http.server_init(&server)
    defer http.server_destroy(&server)

    // Serve static files from directory
    http.serve_static(&server.router, "/public", "public")

    // Health endpoint
    http.get(&server.router, "/health", proc(req: ^http.Request, res: ^http.Response) {
        http.response_json(res, `{"status":"ok"}`)
    })

    // Dynamic echo endpoint
    http.post(&server.router, "/echo", proc(req: ^http.Request, res: ^http.Response) {
        http.response_json(res, fmt.tprintf(`{{"received":%s}}`, string(req.body)))
    })

    fmt.println("Starting HTTP server on 0.0.0.0:8080 ...")
    http.server_listen_and_serve(&server, "0.0.0.0", 8080)
}
```

---

## ⚙️ Environment Variables

- **`WASIX_RUNNER`**: Command used by `odin-wasix run` to execute the WebAssembly binary (defaults to `wasmer run --net`). For example, to use a custom runner:
  ```bash
  export WASIX_RUNNER="wasmer run --net --enable-threads"
  ```
- **`ODIN_WASIX_PATH`**: Explicit path to the `odin-wasix` root directory containing `pkg/wasix`. When set, `odin-wasix` uses this path regardless of current working directory.

---

## 📄 License

This project is licensed under the [Mozilla Public License Version 2.0](LICENSE) (MPL 2.0).
