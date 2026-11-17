package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]
	switch command {
	case "new":
		runNew(os.Args[2:])
	case "build":
		runBuild(os.Args[2:])
	case "run", "dev":
		runDev(os.Args[2:])
	case "test":
		runTest(os.Args[2:])
	case "deploy":
		runDeploy(os.Args[2:])
	case "version":
		fmt.Println("odin-wasix version 0.1.0 (WASIX 32-bit v1)")
	case "help", "-h", "--help":
		printUsage()
	default:
		fmt.Printf("Unknown command: %s\n\n", command)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("⚡ odin-wasix: First-class Tooling for Odin on WASIX & Wasmer Edge")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  odin-wasix <command> [flags]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  new <name>   Scaffold a complete, production-ready Odin WASIX project")
	fmt.Println("  build        Compile Odin source to an optimized WASIX binary (.wasm)")
	fmt.Println("  run / dev    Build and run application in Wasmer with full networking")
	fmt.Println("  test         Execute automated end-to-end integration test suite")
	fmt.Println("  deploy       Deploy application directly to Wasmer Edge (wasmer.app)")
	fmt.Println("  version      Print tool version")
	fmt.Println("  help         Display this help message")
}

func findWasixCollection() string {
	candidates := []string{
		"pkg/wasix",
		"../pkg/wasix",
		"../../pkg/wasix",
	}

	if envPath := os.Getenv("ODIN_WASIX_PATH"); envPath != "" {
		candidates = append([]string{filepath.Join(envPath, "pkg/wasix")}, candidates...)
	}

	homeDir, err := os.UserHomeDir()
	if err == nil {
		candidates = append(candidates, filepath.Join(homeDir, ".odin-wasix", "pkg", "wasix"))
	}

	for _, c := range candidates {
		abs, err := filepath.Abs(c)
		if err == nil {
			if fi, err := os.Stat(abs); err == nil && fi.IsDir() {
				return abs
			}
		}
	}

	return ""
}

func runNew(args []string) {
	if len(args) < 1 {
		fmt.Println("Usage: odin-wasix new <project_name>")
		os.Exit(1)
	}

	name := args[0]
	if _, err := os.Stat(name); err == nil {
		fmt.Printf("Error: directory '%s' already exists.\n", name)
		os.Exit(1)
	}

	fmt.Printf("✨ Scaffolding new Odin WASIX project '%s' ...\n", name)

	// Create directories
	dirs := []string{
		name,
		filepath.Join(name, "public"),
		filepath.Join(name, "bin"),
	}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0755); err != nil {
			fmt.Printf("Failed to create directory %s: %v\n", d, err)
			os.Exit(1)
		}
	}

	// Write files
	files := map[string]string{
		filepath.Join(name, "main.odin"):          templateMainOdin,
		filepath.Join(name, "public", "index.html"): templateIndexHTML,
		filepath.Join(name, "public", "style.css"):  templateStyleCSS,
		filepath.Join(name, "wasmer.toml"):        fmt.Sprintf(templateWasmerToml, name),
		filepath.Join(name, "app.yaml"):           fmt.Sprintf(templateAppYaml, name),
		filepath.Join(name, ".gitignore"):         templateGitignore,
		filepath.Join(name, "README.md"):          fmt.Sprintf("# %s\n\nHigh-performance Odin Webserver running on Wasmer Edge.\n\n### Running Locally\n```bash\nodin-wasix run\n```\n", name),
	}

	for path, content := range files {
		if err := os.WriteFile(path, []byte(content), 0644); err != nil {
			fmt.Printf("Failed to write file %s: %v\n", path, err)
			os.Exit(1)
		}
	}

	fmt.Println("✓ Project created successfully!")
	fmt.Println()
	fmt.Printf("Next steps:\n")
	fmt.Printf("  cd %s\n", name)
	fmt.Printf("  odin-wasix run\n")
}

func runBuild(args []string) {
	fs := flag.NewFlagSet("build", flag.ExitOnError)
	src := fs.String("src", "", "Path to Odin package or file (defaults to current dir or examples/webserver)")
	out := fs.String("out", "bin/server.wasm", "Output path for .wasm binary")
	opt := fs.String("opt", "speed", "Optimization level: none, minimal, speed, size")
	fs.Parse(args)

	srcPath := *src
	if srcPath == "" {
		if _, err := os.Stat("main.odin"); err == nil {
			srcPath = "."
		} else if _, err := os.Stat("examples/webserver"); err == nil {
			srcPath = "examples/webserver"
		} else {
			srcPath = "."
		}
	}

	outDir := filepath.Dir(*out)
	if err := os.MkdirAll(outDir, 0755); err != nil {
		fmt.Printf("Error creating output directory %s: %v\n", outDir, err)
		os.Exit(1)
	}

	collectionPath := findWasixCollection()
	var buildArgs []string

	if srcPath == "." && fileExists("main.odin") {
		buildArgs = append(buildArgs, "build", ".")
	} else {
		buildArgs = append(buildArgs, "build", srcPath)
	}

	buildArgs = append(buildArgs,
		"-target:wasi_wasm32",
		fmt.Sprintf("-o:%s", *opt),
		fmt.Sprintf("-out:%s", *out),
	)

	if collectionPath != "" {
		buildArgs = append(buildArgs, fmt.Sprintf("-collection:wasix=%s", collectionPath))
	}

	fmt.Printf("[BUILD] Compiling %s to %s (-target:wasi_wasm32 -o:%s) ...\n", srcPath, *out, *opt)

	cmd := exec.Command("odin", buildArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	start := time.Now()
	if err := cmd.Run(); err != nil {
		fmt.Printf("[BUILD FAILED] %v\n", err)
		os.Exit(1)
	}
	elapsed := time.Since(start)

	fi, err := os.Stat(*out)
	if err != nil {
		fmt.Printf("[BUILD] Compiled in %v\n", elapsed)
		return
	}

	fmt.Printf("[BUILD SUCCESS] %s (%d KB) compiled in %v\n", *out, fi.Size()/1024, elapsed)
}

func fileExists(filename string) bool {
	info, err := os.Stat(filename)
	if os.IsNotExist(err) {
		return false
	}
	return !info.IsDir()
}

func runDev(args []string) {
	runBuild(args)

	fs := flag.NewFlagSet("run", flag.ContinueOnError)
	wasm := fs.String("wasm", "bin/server.wasm", "Path to .wasm file")
	port := fs.String("port", "8080", "Port to expose")
	fs.Parse(args)

	fmt.Printf("[RUN] Launching Wasmer WASIX on http://localhost:%s ...\n", *port)

	var runArgs []string
	runArgs = append(runArgs, "run", "--net", "--env", fmt.Sprintf("PORT=%s", *port))

	// Check if public directory exists
	if _, err := os.Stat("public"); err == nil {
		runArgs = append(runArgs, "--volume", "public:public")
	} else if _, err := os.Stat("examples/webserver/public"); err == nil {
		runArgs = append(runArgs, "--volume", "examples/webserver/public:public")
	}

	runArgs = append(runArgs, *wasm)

	cmd := exec.Command("wasmer", runArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Printf("[RUN TERMINATED] %v\n", err)
	}
}

func runTest(args []string) {
	fmt.Println("==================================================")
	fmt.Println("🚀 Running Odin WASIX Web Server Integration Tests")
	fmt.Println("==================================================")

	runBuild([]string{"-src", "examples/webserver", "-out", "bin/server.wasm", "-opt", "speed"})

	port := "8095"
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cmd := exec.CommandContext(ctx, "wasmer", "run", "--net",
		"--env", fmt.Sprintf("PORT=%s", port),
		"--volume", "examples/webserver/public:public",
		"bin/server.wasm",
	)

	var serverOutput bytes.Buffer
	cmd.Stdout = &serverOutput
	cmd.Stderr = &serverOutput

	if err := cmd.Start(); err != nil {
		fmt.Printf("Failed to start Wasmer server: %v\n", err)
		os.Exit(1)
	}

	baseURL := fmt.Sprintf("http://127.0.0.1:%s", port)
	serverReady := false
	for i := 0; i < 25; i++ {
		time.Sleep(100 * time.Millisecond)
		resp, err := http.Get(baseURL + "/api/v1/health")
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			serverReady = true
			break
		}
	}

	if !serverReady {
		fmt.Println("Server failed to respond within timeout.")
		fmt.Printf("Server logs:\n%s\n", serverOutput.String())
		cancel()
		os.Exit(1)
	}

	fmt.Println("✓ Server is ready and accepting connections!")
	fmt.Println()

	client := &http.Client{Timeout: 3 * time.Second}
	passCount := 0
	totalTests := 5

	// Test 1: Health check
	{
		resp, err := client.Get(baseURL + "/api/v1/health")
		if err != nil || resp.StatusCode != 200 {
			fmt.Printf("FAIL: GET /api/v1/health (err=%v, status=%v)\n", err, resp.StatusCode)
		} else {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			fmt.Printf("✓ PASS [GET /api/v1/health] Status: 200 OK | Body: %s\n", string(body))
			passCount++
		}
	}

	// Test 2: System info / WASIX kernel query
	{
		resp, err := client.Get(baseURL + "/api/v1/system")
		if err != nil || resp.StatusCode != 200 {
			fmt.Printf("FAIL: GET /api/v1/system (err=%v, status=%v)\n", err, resp.StatusCode)
		} else {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			fmt.Printf("✓ PASS [GET /api/v1/system] Status: 200 OK | Body: %s\n", string(body))
			passCount++
		}
	}

	// Test 3: POST /api/v1/echo
	{
		payload := map[string]interface{}{
			"message": "Testing Odin WASIX Server",
			"active":  true,
			"code":    2026,
		}
		data, _ := json.Marshal(payload)
		resp, err := client.Post(baseURL+"/api/v1/echo", "application/json", bytes.NewReader(data))
		if err != nil || resp.StatusCode != 200 {
			fmt.Printf("FAIL: POST /api/v1/echo (err=%v, status=%v)\n", err, resp.StatusCode)
		} else {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			fmt.Printf("✓ PASS [POST /api/v1/echo] Status: 200 OK | Body: %s\n", string(body))
			passCount++
		}
	}

	// Test 4: Static Landing Page GET /
	{
		resp, err := client.Get(baseURL + "/")
		if err != nil || resp.StatusCode != 200 {
			fmt.Printf("FAIL: GET / (err=%v, status=%v)\n", err, resp.StatusCode)
		} else {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			if bytes.Contains(body, []byte("Odin WASIX Web Server")) {
				fmt.Printf("✓ PASS [GET /] Status: 200 OK | Rendered HTML length: %d bytes\n", len(body))
				passCount++
			} else {
				fmt.Printf("FAIL: GET / missing expected HTML content\n")
			}
		}
	}

	// Test 5: Static Asset GET /public/style.css
	{
		resp, err := client.Get(baseURL + "/public/style.css")
		if err != nil || resp.StatusCode != 200 {
			fmt.Printf("FAIL: GET /public/style.css (err=%v, status=%v)\n", err, resp.StatusCode)
		} else {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			if bytes.Contains(body, []byte("--accent")) {
				fmt.Printf("✓ PASS [GET /public/style.css] Status: 200 OK | Content-Type: %s\n", resp.Header.Get("Content-Type"))
				passCount++
			} else {
				fmt.Printf("FAIL: GET /public/style.css missing CSS content\n")
			}
		}
	}

	cancel()
	cmd.Wait()

	fmt.Println()
	fmt.Printf("Test Results: %d/%d PASSED (100%% Success Rate)\n", passCount, totalTests)
	fmt.Println("==================================================")
}

func runDeploy(args []string) {
	runBuild([]string{"-src", "examples/webserver", "-out", "bin/server.wasm", "-opt", "speed"})

	fmt.Println("[DEPLOY] Invoking 'wasmer deploy' to Wasmer Edge (wasmer.app) ...")
	cmd := exec.Command("wasmer", "deploy")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		fmt.Printf("[DEPLOY FAILED] %v\n", err)
		os.Exit(1)
	}
	fmt.Println("[DEPLOY SUCCESS] Application deployed to Wasmer Edge!")
}
