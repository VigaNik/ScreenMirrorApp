#!/bin/bash
cd "$(dirname "$0")"
swift build -c release --product VirtualDisplayTool 2>&1 | grep -v "^Build complete\|^warning\|planning\|Compiling\|Linking"
echo ""
.build/release/VirtualDisplayTool
