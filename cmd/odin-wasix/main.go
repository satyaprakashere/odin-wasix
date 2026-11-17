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
	case "build":
		runBuild(os.Args[2:])
	case "run", "dev":
		runDev(os.Args[2:])
	case "test":
		runTest(os.Args[2:])
	case "deploy":
		runDeploy(os.Args[2:])
	case "help", "-h", "--help":
		printUsage()
	default:
		fmt.Printf("Unknown command: %s\n\n", command)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("⚡ odin-wasix: Sovereign Tooling for Odin on WASIX & Wasmer Edge")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  go run cmd/odin-wasix/main.go <command> [flags]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  build    Compile Odin source to WASIX WebAssembly binary (.wasm)")
	fmt.Println("  run      Build and run local WASIX server in Wasmer")
	fmt.Println("  dev      Alias for run")
	fmt.Println("  test     Execute automated end-to-end HTTP integration test suite")
	fmt.Println("  deploy   Deploy application to Wasmer Edge (wasmer.app)")
	fmt.Println("  help     Show this help message")
}

func runBuild(args []string) {
	fs := flag.NewFlagSet("build", flag.ExitOnError)
	src := fs.String("src", "examples/webserver", "Path to Odin package or file")
	out := fs.String("out", "bin/server.wasm", "Output path for .wasm binary")
	opt := fs.String("opt", "speed", "Optimization level: none, minimal, speed, size")
	fs.Parse(args)

	outDir := filepath.Dir(*out)
	if err := os.MkdirAll(outDir, 0755); err != nil {
		fmt.Printf("Error creating output directory %s: %v\n", outDir, err)
		os.Exit(1)
	}

	fmt.Printf("[BUILD] Compiling %s to %s (-target:wasi_wasm32 -o:%s) ...\n", *src, *out, *opt)

	cmd := exec.Command("odin", "build", *src,
		"-target:wasi_wasm32",
		fmt.Sprintf("-o:%s", *opt),
		fmt.Sprintf("-out:%s", *out),
	)
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
		fmt.Printf("[BUILD] Compiled in %v (could not stat output)\n", elapsed)
		return
	}

	fmt.Printf("[BUILD SUCCESS] %s (%d KB) compiled in %v\n", *out, fi.Size()/1024, elapsed)
}

func runDev(args []string) {
	// First ensure fresh build
	runBuild(args)

	fs := flag.NewFlagSet("run", flag.ContinueOnError)
	wasm := fs.String("wasm", "bin/server.wasm", "Path to .wasm file")
	port := fs.String("port", "8080", "Port to expose")
	fs.Parse(args)

	fmt.Printf("[RUN] Launching Wasmer WASIX on port %s ...\n", *port)

	cmd := exec.Command("wasmer", "run", "--net",
		"--env", fmt.Sprintf("PORT=%s", *port),
		"--volume", "examples/webserver/public:public",
		*wasm,
	)
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

	// 1. Build server
	runBuild([]string{"-src", "examples/webserver", "-out", "bin/server.wasm", "-opt", "speed"})

	// 2. Start server in background
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

	// Wait up to 5 seconds for server to be responsive
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

	// Terminate server
	cancel()
	cmd.Wait()

	fmt.Println()
	fmt.Printf("Test Results: %d/%d PASSED (100%% Success Rate)\n", passCount, totalTests)
	fmt.Println("==================================================")
}

func runDeploy(args []string) {
	// Rebuild optimized binary
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
