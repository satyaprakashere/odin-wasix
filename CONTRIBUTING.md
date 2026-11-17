# Contributing to odin-wasix

Thank you for your interest in contributing to **odin-wasix**! We welcome bug reports, feature suggestions, documentation improvements, and pull requests.

## Development Setup

### Requirements
- **Odin Compiler**: `dev-2024` or newer (available via [odin-lang.org](https://odin-lang.org/))
- **Wasmer**: `7.x` or newer (available via [wasmer.io](https://wasmer.io/)) or any WASIX-compliant runtime
- **Bash & curl**: Standard Unix tools for CLI driver and integration testing

### Running Tests
To run the automated integration test suite:
```bash
./odin-wasix test
```

### Building the Native CLI
To build the native binary CLI with Odin:
```bash
odin build cmd/odin-wasix -out:bin/odin-wasix
./bin/odin-wasix help
```

## Guidelines
1. **Zero External Dependencies**: Odin WASIX packages in `pkg/wasix` must remain zero-dependency and rely exclusively on Odin language primitives and raw WASIX (`wasix_32v1`) system calls.
2. **Pure Odin & Bash Only**: The project maintains zero external language dependencies (no Python, no Go required for users).
3. **Conventional Commits**: Please format commit messages using Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
4. **Devanagari Script**: Any Indic or philosophical terms must be rendered in native Devanagari script (e.g., **धर्म**, **कर्म**).
