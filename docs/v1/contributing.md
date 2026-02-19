# Contributing to Zenn

## Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+ (with Swift 5.9+)
- Lua 5.4 (`brew install lua`)

## Building

```bash
# Clone
git clone https://github.com/YOUR_USERNAME/zenn.git
cd zenn

# Resolve dependencies
swift package resolve

# Build (debug)
swift build

# Build (release)
swift build -c release
```

## Running

```bash
# Run the menu bar app
swift run zenn-app

# Run the CLI
swift run zenn --help
```

**Note:** The app requires Accessibility permission. On first launch, macOS will prompt you to grant access in System Settings > Privacy & Security > Accessibility.

## Testing

```bash
# Run all tests
swift test

# Run a specific test target
swift test --filter ZennCoreTests

# Run a specific test case
swift test --filter ZennCoreTests.TreeOperationsTests
```

## Project Structure

```
Sources/
  ZennShared/     # Shared types (no platform deps)
  CPrivateAPI/    # C bridge for private macOS APIs
  ZennMacOS/      # macOS API abstraction
  ZennCore/       # Core tiling engine
  ZennLua/        # Lua configuration engine
  ZennIPC/        # IPC server (Unix socket + HTTP)
  ZennApp/        # Menu bar application
  ZennCLI/        # CLI client
  CLua/           # Lua 5.4 system library
  CLuaShim/       # C shim for Lua macros
Tests/
  ZennCoreTests/  # Core engine tests
  ZennLuaTests/   # Lua bridge tests
  ZennIPCTests/   # IPC protocol tests
```

See [architecture.md](architecture.md) for module dependency graph and detailed descriptions.

## Code Style

- Follow Swift API Design Guidelines
- Use `public` access control for module APIs, `internal` for implementation details
- Prefer `struct` over `class` unless reference semantics are required (tree nodes need `class` for parent pointers)
- Use `guard` for early returns
- Keep files under 300 lines where practical
- Name files after the primary type they contain

## Pull Request Process

1. Fork the repository and create a feature branch from `main`
2. Write tests for new functionality
3. Ensure all tests pass: `swift test`
4. Ensure the project builds in release mode: `swift build -c release`
5. Write clear commit messages describing the "why", not just the "what"
6. Open a PR against `main` with a description of the changes

## Architecture Guidelines

- **ZennShared** has zero platform dependencies. Only Foundation types and custom value types.
- **ZennMacOS** wraps all macOS-specific APIs (Accessibility, CoreGraphics, AppKit). No other module should import AppKit or ApplicationServices directly.
- **ZennCore** contains the tiling engine logic. It depends on ZennMacOS for window manipulation but is otherwise platform-agnostic in its algorithms.
- **ZennApp** is the entry point. It wires all components together via `TilingCoordinator`.
- All tree mutations must go through `TreeOperations`. Direct manipulation of `ContainerNode.children` is reserved for `TreeOperations` and `TreeNormalization`.
- After every tree mutation, call `TreeNormalization.normalize(root:)` to maintain tree invariants.

## Reporting Issues

Please include:
- macOS version
- Zenn version (`zenn --version`)
- Steps to reproduce
- Expected vs actual behavior
- Relevant log output (check `~/Library/Logs/zenn.log` if running as a service)

## License

By contributing, you agree that your contributions will be licensed under the GPL v3 license.
