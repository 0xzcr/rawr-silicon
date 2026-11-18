#!/bin/bash
# Run every test: shell scripts, then the Swift mic analysis.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

bash tests/test_scripts.sh

swiftc -O -swift-version 5 app/MicAnalysis.swift tests/MicAnalysisTests/main.swift -o build/mic-analysis-tests
build/mic-analysis-tests
