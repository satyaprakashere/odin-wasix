# Contributing to odin-wasix

Thank you for your interest in contributing to **odin-wasix**! We welcome bug reports, feature suggestions, documentation improvements, and pull requests.

## Development Setup

### Requirements
- **Odin Compiler**: `dev-2024` or newer (available via [odin-lang.org](https://odin-lang.org/))
- **Wasmer**: `7.x` or newer (available via [wasmer.io](https://wasmer.io/))
- **Go**: `1.20` or newer (for the `odin-wasix` CLI and test runner)

### Running Tests
To run the automated integration test suite:
```bash
go run cmd/odin-wasix/main.go test
```

### Building the CLI
To build the CLI tool locally:
```bash
go build -o odin-wasix cmd/odin-wasix/main.go
```

## Guidelines
1. **Zero External Dependencies**: Odin WASIX packages in `pkg/wasix` must remain zero-dependency and rely exclusively on Odin language primitives and raw WASIX (`wasix_32v1`) system calls.
2. **Go Scripts Only**: Any build automation, codegen scripts, and CLI tooling must be written strictly in **Go**. Python scripts are strictly prohibited.
3. **Conventional Commits**: Please format commit messages using Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
4. **Devanagari Script**: Any Indic or philosophical terms must be rendered in native Devanagari script (e.g., **धर्म**, **कर्म**).
