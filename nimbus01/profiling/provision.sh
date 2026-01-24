#!/bin/bash
# Provision dependencies for image processing profiling scripts

set -e

echo "=== Installing system dependencies ==="
sudo apt update
sudo apt install -y python3-pip libvips-dev

echo ""
echo "=== Installing Python dependencies ==="
pip3 install Pillow pyvips numpy scipy

echo ""
echo "=== Verifying installation ==="
python3 -c "import PIL; print(f'Pillow version: {PIL.__version__}')"
python3 -c "import pyvips; print(f'pyvips version: {pyvips.__version__}')"
python3 -c "import pyvips; print(f'libvips version: {pyvips.version(0)}.{pyvips.version(1)}.{pyvips.version(2)}')"

echo ""
echo "=== Done! ==="
echo "You can now run:"
echo "  ./generate_test_images.py --preset 24mp"
echo "  ./profile_vips.py --input ./sample_input/24mp"
