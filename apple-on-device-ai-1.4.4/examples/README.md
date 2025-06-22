# Apple AI + Vercel AI SDK Examples

This folder contains comprehensive examples demonstrating how to use the Apple AI library with the Vercel AI SDK.

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3)
- Apple Intelligence enabled
- Bun or Node.js 23+

## Running Examples

### Run All Examples

```bash
bun run examples
```

### Run Individual Examples

```bash
# Basic text generation
bun run examples:basic

# Streaming text generation
bun run examples:streaming

# Structured object generation
bun run examples:object

# Comprehensive example with all features
bun run examples:comprehensive
```

### Direct Execution

You can also run examples directly:

```bash
bun run examples/01-basic-generation.ts
bun run examples/02-streaming.ts
bun run examples/03-object-generation.ts
bun run examples/04-comprehensive.ts
```

## Examples Overview

### 1. Basic Generation (`01-basic-generation.ts`)

Demonstrates basic text generation using the AI SDK with different temperature settings:

- Simple Q&A
- Creative writing
- Technical explanations

### 2. Streaming (`02-streaming.ts`)

Shows real-time streaming text generation:

- Story generation with streaming output
- Technical explanations with different temperatures
- Demonstrates how to handle streaming responses

### 3. Object Generation (`03-object-generation.ts`)

Structured data generation using Zod schemas:

- Recipe generation with ingredients and instructions
- Character profile creation
- Type-safe object parsing

### 4. Comprehensive (`04-comprehensive.ts`)

Complete workflow combining all features:

- Basic text generation
- Structured analysis
- Streaming detailed explanations
- Follow-up question generation
- Performance tracking

## Key Features Demonstrated

### AI SDK Integration

- ✅ `generateText()` - Basic text generation
- ✅ `streamText()` - Real-time streaming
- ✅ `generateObject()` - Structured data with Zod

### Apple AI Provider Features

- ✅ Temperature control
- ✅ Token limits
- ✅ Multiple model support
- ✅ OpenAI-compatible API

### Use Cases

- 📝 Content generation
- 🧩 Structured data extraction
- 🌊 Real-time chat interfaces
- 🎯 Task-specific AI workflows

## Error Handling

All examples include comprehensive error handling to demonstrate:

- Graceful degradation
- Meaningful error messages
- Debugging information

## Performance Notes

- Examples include timing and performance metrics
- Streaming examples show character count and timing
- Object generation examples demonstrate schema validation

## Next Steps

After running these examples, you can:

1. Integrate the provider into your Next.js app
2. Build chat interfaces with React
3. Create structured data processing pipelines
4. Develop custom AI workflows

## Troubleshooting

If examples fail:

1. Ensure Apple Intelligence is enabled
2. Check that you're on Apple Silicon
3. Verify dependencies are installed: `bun install`
4. Check for system requirements in the main README
