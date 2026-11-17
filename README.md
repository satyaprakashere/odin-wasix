# Odin-WASIX: WebAssembly System Interface Extensions Target for Odin

> **Experimental toolchain and runtime bindings for compiling Odin programs to the WASIX (WASI Extensions) target on Wasmer Edge.**

---

## 1. Overview

**Odin-WASIX** explores first-class support for compiling the [Odin programming language](https://odin-lang.org/) to WebAssembly with WASIX extensions. 

While upstream Odin supports the base `js_wasm32` and `wasi` targets, WASIX adds:
- Multithreading (`wasm32-wasi-threads` / `pthread` emulation).
- Full POSIX socket networking (`connect`, `listen`, `bind`, `accept`).
- Process control primitives (`fork`, `exec`, `wait`).
- Direct compatibility with Wasmer Edge edge-deployments.

---

## 2. Status & Road Map

- [ ] LLVM target specification mapping for `wasm32-wasix`.
- [ ] Core library OS layer bindings (`core:sys/wasix`).
- [ ] Integration with `wasmr` interpreter and `websites` WASIX edge servers.
- [ ] Automated build and packaging via `opm`.

---

## 3. Usage & Compilation

```bash
# Compilation once toolchain definitions are staged:
odin build src/ -target:wasix -out:app.wasm
```
