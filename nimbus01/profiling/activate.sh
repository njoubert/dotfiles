#!/bin/bash
# Activate the profiling virtual environment
# Usage: source activate.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Error: Virtual environment not found. Run ./provision.sh first."
    return 1 2>/dev/null || exit 1
fi

source "$SCRIPT_DIR/venv/bin/activate"
echo "Activated profiling venv. Run 'deactivate' to exit."
