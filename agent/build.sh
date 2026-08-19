#!/bin/bash
# Build script for cross-platform compilation

echo "Building Native Go Host Agent..."
echo ""

# Create bin directory
mkdir -p bin

# Build for Windows
echo "[1/3] Building for Windows (amd64)..."
GOOS=windows GOARCH=amd64 go build -o bin/host-agent-windows.exe main.go
if [ $? -eq 0 ]; then
    echo "✓ Windows binary: bin/host-agent-windows.exe"
else
    echo "✗ Windows build failed"
fi

# Build for Linux
echo "[2/3] Building for Linux (amd64)..."
GOOS=linux GOARCH=amd64 go build -o bin/host-agent-linux main.go
if [ $? -eq 0 ]; then
    echo "✓ Linux binary: bin/host-agent-linux"
else
    echo "✗ Linux build failed"
fi

# Build for macOS
echo "[3/3] Building for macOS (amd64)..."
GOOS=darwin GOARCH=amd64 go build -o bin/host-agent-macos main.go
if [ $? -eq 0 ]; then
    echo "✓ macOS binary: bin/host-agent-macos"
else
    echo "✗ macOS build failed"
fi

echo ""
echo "Build complete!"
echo ""
echo "To run:"
echo "  Windows: bin/host-agent-windows.exe"
echo "  Linux:   ./bin/host-agent-linux"
echo "  macOS:   ./bin/host-agent-macos"
