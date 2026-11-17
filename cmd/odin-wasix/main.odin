package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

VERSION :: "0.1.0"

main :: proc() {
	args := os.args
	if len(args) < 2 {
		print_usage()
		os.exit(1)
	}

	command := args[1]
	switch command {
	case "new":
		if len(args) < 3 {
			fmt.println("Error: Project name required. Usage: odin-wasix new <name>")
			os.exit(1)
		}
		cmd_new(args[2])
	case "build":
		cmd_build(args[2:])
	case "check":
		cmd_check(args[2:])
	case "run":
		cmd_run(args[2:])
	case "test":
		cmd_test(args[2:])
	case "version", "-v", "--version":
		fmt.printfln("odin-wasix version %s (WASIX 32-bit v1)", VERSION)
	case "help", "-h", "--help":
		print_usage()
	case:
		// Default to build if first argument looks like a source or flag
		cmd_build(args[1:])
	}
}

print_usage :: proc() {
	fmt.printfln("⚡ odin-wasix: General WASIX compiler driver for Odin (%s)", VERSION)
	fmt.println("   (Equivalent of wasixcc for the Odin programming language)")
	fmt.println()
	fmt.println("Usage:")
	fmt.println("  odin-wasix <command> [flags] [source...]")
	fmt.println()
	fmt.println("Commands:")
	fmt.println("  build <src> [flags]   Compile Odin source to a WASIX WebAssembly binary (.wasm)")
	fmt.println("  run <src> [flags]     Compile and run in a WASIX runtime (Wasmer)")
	fmt.println("  check <src> [flags]   Type-check Odin source code for WASIX target")
	fmt.println("  new <name>            Scaffold a new WASIX-ready Odin application")
	fmt.println("  test                  Execute automated WASIX integration test suite")
	fmt.println("  version               Print odin-wasix version")
	fmt.println("  help                  Show this help message")
	fmt.println()
	fmt.println("Options passed to Odin compiler:")
	fmt.println("  -out:<path>           Output binary filename (default: bin/<name>.wasm)")
	fmt.println("  -o:speed|-o:size      Optimization level (none, minimal, size, speed)")
	fmt.println("  -file                 Compile a single file rather than a directory package")
	fmt.println("  -show-timings         Display compiler phase durations")
	fmt.println()
	fmt.println("Environment Variables:")
	fmt.println("  WASIX_RUNNER          WASIX runtime command (default: 'wasmer run --net')")
	fmt.println("  ODIN_WASIX_PATH       Path to the odin-wasix SDK / pkg collection")
	fmt.println()
	fmt.println("Examples:")
	fmt.println("  odin-wasix build main.odin -file -out:app.wasm")
	fmt.println("  odin-wasix run main.odin -file")
	fmt.println("  odin-wasix check .")
	fmt.println("  odin-wasix new my-service")
}

find_wasix_collection :: proc() -> string {
	candidates := [?]string{
		"pkg/wasix",
		"../pkg/wasix",
		"../../pkg/wasix",
	}

	if env_path := os.get_env("ODIN_WASIX_PATH", context.temp_allocator); len(env_path) > 0 {
		p := fmt.tprintf("%s/pkg/wasix", env_path)
		if os.is_directory(p) do return p
	}

	if exe_dir, err := os.get_executable_directory(context.temp_allocator); err == nil {
		p := fmt.tprintf("%s/pkg/wasix", exe_dir)
		if os.is_directory(p) do return p
		p_up := fmt.tprintf("%s/../pkg/wasix", exe_dir)
		if os.is_directory(p_up) do return p_up
	}

	if cwd, err := os.get_working_directory(context.temp_allocator); err == nil {
		p := fmt.tprintf("%s/pkg/wasix", cwd)
		if os.is_directory(p) do return p
	}

	for c in candidates {
		if os.is_directory(c) do return c
	}

	if home := os.get_env("HOME", context.temp_allocator); len(home) > 0 {
		p := fmt.tprintf("%s/.odin-wasix/pkg/wasix", home)
		if os.is_directory(p) do return p
	}

	return ""
}

cmd_new :: proc(name: string) {
	if os.exists(name) {
		fmt.printfln("Error: Directory '%s' already exists.", name)
		os.exit(1)
	}

	fmt.printfln("✨ Scaffolding new Odin WASIX project '%s' ...", name)

	os.make_directory(name)
	os.make_directory(fmt.tprintf("%s/bin", name))

	_ = os.write_entire_file_from_string(fmt.tprintf("%s/main.odin", name), TEMPLATE_MAIN_ODIN)
	_ = os.write_entire_file_from_string(fmt.tprintf("%s/.gitignore", name), TEMPLATE_GITIGNORE)

	readme := fmt.tprintf(TEMPLATE_README, name, name, name)
	_ = os.write_entire_file_from_string(fmt.tprintf("%s/README.md", name), readme)

	fmt.println("✓ Project created successfully!")
	fmt.println()
	fmt.println("Next steps:")
	fmt.printfln("  cd %s", name)
	fmt.println("  odin-wasix run main.odin -file")
}

cmd_build :: proc(args: []string) {
	cmd_args := make([dynamic]string, context.temp_allocator)
	append(&cmd_args, "odin", "build")

	// Append user arguments
	for a in args {
		append(&cmd_args, a)
	}

	// Always inject WASIX target
	append(&cmd_args, "-target:wasi_wasm32")

	// Inject collection path if found
	col_path := find_wasix_collection()
	if len(col_path) > 0 {
		append(&cmd_args, fmt.tprintf("-collection:wasix=%s", col_path))
	}

	desc := os.Process_Desc{
		command = cmd_args[:],
	}

	state, stdout, stderr, err := os.process_exec(desc, context.temp_allocator)
	if len(stdout) > 0 do fmt.print(string(stdout))
	if len(stderr) > 0 do fmt.eprint(string(stderr))

	if err != nil || state.exit_code != 0 {
		os.exit(state.exit_code != 0 ? state.exit_code : 1)
	}
}

cmd_check :: proc(args: []string) {
	cmd_args := make([dynamic]string, context.temp_allocator)
	append(&cmd_args, "odin", "check")

	for a in args {
		append(&cmd_args, a)
	}

	append(&cmd_args, "-target:wasi_wasm32")

	col_path := find_wasix_collection()
	if len(col_path) > 0 {
		append(&cmd_args, fmt.tprintf("-collection:wasix=%s", col_path))
	}

	desc := os.Process_Desc{
		command = cmd_args[:],
	}

	state, stdout, stderr, err := os.process_exec(desc, context.temp_allocator)
	if len(stdout) > 0 do fmt.print(string(stdout))
	if len(stderr) > 0 do fmt.eprint(string(stderr))

	if err != nil || state.exit_code != 0 {
		os.exit(state.exit_code != 0 ? state.exit_code : 1)
	}
}

cmd_run :: proc(args: []string) {
	out_wasm := ""
	user_args := make([dynamic]string, context.temp_allocator)
	build_args := make([dynamic]string, context.temp_allocator)
	past_delimiter := false

	for arg in args {
		if arg == "--" && !past_delimiter {
			past_delimiter = true
			continue
		}

		if past_delimiter {
			append(&user_args, arg)
		} else {
			if strings.has_prefix(arg, "-out:") {
				out_wasm = arg[len("-out:"):]
			}
			append(&build_args, arg)
		}
	}

	// If already a .wasm file, run directly
	if len(args) >= 1 && strings.has_suffix(args[0], ".wasm") && os.exists(args[0]) {
		exec_wasm(args[0], user_args[:])
		return
	}

	if out_wasm == "" {
		out_wasm = "/tmp/odin_wasix_run.wasm"
		append(&build_args, fmt.tprintf("-out:%s", out_wasm))
	}

	cmd_build(build_args[:])

	exec_wasm(out_wasm, user_args[:])
}

exec_wasm :: proc(wasm_file: string, user_args: []string) {
	runner := "wasmer"
	run_args := make([dynamic]string, context.temp_allocator)

	if runner_env := os.get_env("WASIX_RUNNER", context.temp_allocator); len(runner_env) > 0 {
		parts := strings.split(runner_env, " ", context.temp_allocator)
		for p in parts {
			if len(p) > 0 do append(&run_args, p)
		}
	} else {
		append(&run_args, runner, "run", "--net")
	}

	if os.is_directory("public") {
		append(&run_args, "--volume", "public:public")
	} else if os.is_directory("examples/webserver/public") {
		append(&run_args, "--volume", "examples/webserver/public:public")
	}

	append(&run_args, wasm_file)

	if len(user_args) > 0 {
		append(&run_args, "--")
		for a in user_args {
			append(&run_args, a)
		}
	}

	desc := os.Process_Desc{
		command = run_args[:],
	}

	state, stdout, stderr, err := os.process_exec(desc, context.temp_allocator)
	if len(stdout) > 0 do fmt.print(string(stdout))
	if len(stderr) > 0 do fmt.eprint(string(stderr))

	if err != nil || state.exit_code != 0 {
		os.exit(state.exit_code != 0 ? state.exit_code : 1)
	}
}

cmd_test :: proc(args: []string) {
	desc := os.Process_Desc{
		command = []string{"./odin-wasix", "test"},
	}
	state, stdout, stderr, _ := os.process_exec(desc, context.temp_allocator)
	fmt.print(string(stdout))
	if len(stderr) > 0 do fmt.eprint(string(stderr))
	os.exit(state.exit_code)
}

// -----------------------------------------------------------------------------
// Templates
// -----------------------------------------------------------------------------

TEMPLATE_MAIN_ODIN: string : `package main

import "core:fmt"
import "wasix:sys"
import "wasix:net"

main :: proc() {
	fmt.println("⚡ Hello from Odin on WASIX!")

	// Query WASIX system information
	pid: sys.pid_t
	sys.proc_id(&pid)

	parallelism: uint
	sys.thread_parallelism(&parallelism)

	fmt.printfln("Process ID:          %d", pid)
	fmt.printfln("Available Hardware:  %d threads", parallelism)

	// Networking & Sockets
	listener, err := net.listen_tcp_str("0.0.0.0", 8080)
	if err != .SUCCESS {
		fmt.printfln("Failed to bind socket: %v", err)
		return
	}
	defer net.close_listener(&listener)

	fmt.println("Listening on http://0.0.0.0:8080 ...")
}
`

TEMPLATE_GITIGNORE: string : `bin/
*.wasm
.DS_Store
`

TEMPLATE_README: string : `# %s

General-purpose Odin application compiled for the WASIX platform.

### Build & Run
` + "```bash" + `
# Build WASIX binary
odin-wasix build main.odin -file -out:bin/app.wasm

# Run with WASIX runtime
odin-wasix run main.odin -file
` + "```" + `
`
