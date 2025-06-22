# Build Process for @meridius-labs/apple-on-device-ai

This library has a unique build process due to its dependency on **macOS 26.0+ beta** and **FoundationModels framework**.

## Why Pre-built Binaries?

- **macOS 26+ requirement**: Uses Apple's FoundationModels framework (Apple Intelligence)
- **Beta macOS only**: No CI runners support macOS 26+ beta
- **Complex toolchain**: Requires Xcode 16+, Swift 6+, and Rust
- **Apple Silicon only**: ARM64 architecture requirement

## Build Process Overview

### Local Development (macOS 26+ only)

```bash
# 1. Build native components (Swift + Rust)
bun run build:native

# 2. Build TypeScript
bun run build:ts

# Or build everything locally
bun run build:local
```

### CI/CD & Distribution

```bash
# CI only builds TypeScript (native binaries are pre-built)
bun run build

# Validates pre-built binaries exist
bun run validate-binaries
```

## Directory Structure

```
@meridius-labs/apple-on-device-ai/
├── build/                    # ✅ COMMITTED to git
│   ├── apple_ai_napi.node   # Pre-built Rust N-API addon
│   ├── libappleai.dylib     # Pre-built Swift library
│   └── *.swiftmodule        # Swift module files
├── dist/                    # Built by CI/CD
│   ├── index.js             # CommonJS bundle
│   ├── index.mjs            # ESM bundle
│   └── *.d.ts               # TypeScript definitions
└── native/target/release/   # ❌ NOT committed (too large)
```

## When to Rebuild Native Components

Native components need rebuilding when:

1. **Swift code changes** (`src/apple-ai.swift`)
2. **Rust code changes** (`native/src/lib.rs`)
3. **Dependency updates** (Cargo.toml, Swift frameworks)
4. **New macOS/Xcode version**

## Workflow for Contributors

### For Library Maintainers (with macOS 26+)

```bash
# 1. Make changes to native code
# 2. Rebuild native components
bun run build:native

# 3. Test changes
bun run examples

# 4. Commit BOTH source and binaries
git add build/ src/ native/
git commit -m "Update native components"

# 5. Push - CI will handle TypeScript build
git push
```

### For TypeScript-only Changes

```bash
# 1. Make TypeScript changes
# 2. Test locally (using existing binaries)
bun run build:ts
bun run examples

# 3. Commit (no need to rebuild native)
git add src/
git commit -m "Update TypeScript code"
git push
```

### For Contributors without macOS 26+

```bash
# 1. Make TypeScript-only changes
# 2. Submit PR - maintainer will rebuild native if needed
# 3. CI validates existing binaries work
```

## GitHub Actions Workflow

### CI (`.github/workflows/ci.yml`)

- ✅ Validates pre-built binaries exist
- ✅ Builds TypeScript with tsdown
- ✅ Runs tests
- ✅ Validates package contents
- ❌ Does NOT build native components

### Release (`.github/workflows/release.yml`)

- ✅ Uses pre-built binaries
- ✅ Builds TypeScript
- ✅ Publishes to npm
- ❌ Does NOT build native components

## Binary Validation

The `validate-binaries` script ensures required native files exist:

```javascript
// Checks for required files:
// - build/apple_ai_napi.node
// - build/libappleai.dylib
// - build/*.swiftmodule
```

## NPM Package Contents

When published, the package includes:

```
@meridius-labs/apple-on-device-ai/
├── package.json
├── README.md
├── dist/           # TypeScript build output
│   ├── index.js    # CommonJS
│   ├── index.mjs   # ESM
│   └── *.d.ts      # Types
└── build/          # Pre-built native binaries
    ├── apple_ai_napi.node
    ├── libappleai.dylib
    └── *.swiftmodule
```

## Troubleshooting

### "Missing native binary" error

- **Cause**: `build/` directory missing or incomplete
- **Solution**: Run `bun run build:native` on macOS 26+

### "Wrong architecture" error

- **Cause**: Binaries built for wrong arch (x86_64 vs ARM64)
- **Solution**: Rebuild on Apple Silicon Mac

### "macOS version too old"

- **Cause**: Running on macOS < 26.0
- **Solution**: Upgrade to macOS 26+ beta or use pre-built package

### CI validation fails

- **Cause**: Native binaries not committed to git
- **Solution**: Commit `build/` directory after local build

## Security Considerations

### Code Signing

For distribution, binaries should be code-signed:

```bash
codesign --sign "Developer ID" build/apple_ai_napi.node
codesign --sign "Developer ID" build/libappleai.dylib
```

### Binary Trust

- Pre-built binaries are committed to git for transparency
- All builds use consistent toolchain versions
- Reproducible builds planned for future versions
