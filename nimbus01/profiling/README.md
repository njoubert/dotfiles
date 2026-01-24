# Profiling

This folder contains scripts to profile image processing performance, particularly for benchmarking the VIPS library.

## Results on 2026.01.23

### VIPS Benchmark: M4 vs AMD Ryzen 9955HX (48MP Images, 8485×5657)

| Operation | Format | M4 Mac | Ryzen 9955HX | Δ (M4 faster) |
|-----------|--------|--------|--------------|---------------|
| Thumbnail | JPEG | 147.6 ms | 119 ms | -24% ❌ |
| Thumbnail | WebP | 42.1 ms | 53 ms | +26% ✅ |
| Display | JPEG | 32.1 ms | 44 ms | +37% ✅ |
| Display | WebP | 383.6 ms | 468 ms | +22% ✅ |

#### Summary

| Metric | M4 Mac | Ryzen 9955HX | Winner |
|--------|--------|--------------|--------|
| **JPEG Avg** | 89.8 ms | 81.5 ms | Ryzen (+10%) |
| **WebP Avg** | 212.8 ms | 260.5 ms | M4 (+22%) |
| **All Operations** | 151.3 ms | 171 ms | M4 (+13%) |

#### Takeaways
- **M4 wins on WebP encoding** - significantly faster at both thumbnail and display sizes
- **Ryzen wins on JPEG thumbnails** - 24% faster, likely due to different libjpeg-turbo optimizations
- **M4 display JPEG is surprisingly fast** - 37% faster than Ryzen
- **Overall**: M4 is ~13% faster across all operations, primarily due to WebP performance

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