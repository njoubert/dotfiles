# Profiling

This folder contains scripts to profile image processing performance, particularly for benchmarking the VIPS library.

## Dependencies

```bash
pip install Pillow pyvips
```

You also need libvips installed:
- **Ubuntu/Debian:** `sudo apt install libvips-dev`
- **macOS:** `brew install vips`

## Scripts

### 1. `generate_test_images.py` - Test Image Generator

Generates test images with random color gradients and text overlays showing image number and resolution.

**Presets (3:2 aspect ratio):**
| Preset | Dimensions | Megapixels |
|--------|------------|------------|
| 6mp    | 3000x2000  | 6 MP       |
| 12mp   | 4243x2829  | 12 MP      |
| 24mp   | 6000x4000  | 24 MP      |
| 48mp   | 8485x5657  | 48 MP      |
| 96mp   | 12000x8000 | 96 MP      |

**Usage:**
```bash
# Generate 10 images at 24 megapixels
./generate_test_images.py --preset 24mp

# Generate 5 images at 48mp with custom quality
./generate_test_images.py --preset 48mp --num 5 --quality 90

# Generate all presets
./generate_test_images.py --preset all

# Custom output directory
./generate_test_images.py --preset 24mp --output /path/to/output
```

Images are saved to `sample_input/<preset>/` by default.

### 2. `profile_vips.py` - VIPS Benchmark

Benchmarks VIPS library performance for resizing images to thumbnail and display sizes in JPEG and WebP formats.

**Resize Parameters:**
| Output     | Max Size | Quality |
|------------|----------|---------|
| Display    | 3840px   | 85      |
| Thumbnail  | 800px    | 80      |

**Usage:**
```bash
# Benchmark images in a folder
./profile_vips.py --input ./sample_input/24mp

# Verbose output (per-image timing)
./profile_vips.py --input ./sample_input/48mp --verbose

# Keep output files for inspection
./profile_vips.py --input ./sample_input/24mp --keep-output
```

**Output:**
- Per-operation timing (avg, min, max, stdev)
- Summary by format (JPEG vs WebP)
- Summary by operation (thumbnail vs display)

## Example Workflow

```bash
# 1. Generate test images
./generate_test_images.py --preset 24mp

# 2. Run benchmark
./profile_vips.py --input ./sample_input/24mp --verbose
``` 