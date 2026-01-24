#!/bin/bash
# Provision dependencies for image processing profiling scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Installing system dependencies ==="
sudo apt update
sudo apt install -y python3-pip python3-venv libvips-dev

echo ""
echo "=== Creating Python virtual environment ==="
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Created new virtual environment"
else
    echo "Virtual environment already exists"
fi

echo ""
echo "=== Installing Python dependencies ==="
source venv/bin/activate
pip install -r requirements.txt

echo ""
echo "=== Verifying installation ==="
python3 -c "import PIL; print(f'Pillow version: {PIL.__version__}')"
python3 -c "import pyvips; print(f'pyvips version: {pyvips.__version__}')"
python3 -c "import pyvips; print(f'libvips version: {pyvips.version(0)}.{pyvips.version(1)}.{pyvips.version(2)}')"

echo ""
echo "=== Done! ==="
echo "Activate the virtual environment with:"
echo "  source venv/bin/activate"
echo ""
echo "Then run:"
echo "  ./generate_test_images.py --preset 24mp"
echo "  ./profile_vips.py --input ./sample_input/24mp"
