#!/usr/bin/env python3
"""
Profile VIPS image processing library performance.

Benchmarks resizing images to thumbnail and display sizes
in both JPEG and WebP formats.
"""

import argparse
import os
import statistics
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import List

try:
    import pyvips
except ImportError:
    print("Error: pyvips library required. Install with: pip install pyvips")
    print("Note: You also need libvips installed on your system.")
    print("  Ubuntu/Debian: sudo apt install libvips-dev")
    print("  macOS: brew install vips")
    sys.exit(1)

# Resize parameters
DISPLAY_MAX_SIZE = 3840       # 4K display version
THUMBNAIL_MAX_SIZE = 800      # Thumbnail size
DISPLAY_QUALITY = 85          # Quality for display (JPEG/WebP)
THUMBNAIL_QUALITY = 80        # Quality for thumbnail (JPEG/WebP)

# Supported input formats
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".tiff", ".tif", ".webp"}


@dataclass
class TimingResult:
    """Store timing results for a single operation."""
    operation: str
    format: str
    times_ms: List[float] = field(default_factory=list)
    
    @property
    def count(self) -> int:
        return len(self.times_ms)
    
    @property
    def avg(self) -> float:
        return statistics.mean(self.times_ms) if self.times_ms else 0
    
    @property
    def min(self) -> float:
        return min(self.times_ms) if self.times_ms else 0
    
    @property
    def max(self) -> float:
        return max(self.times_ms) if self.times_ms else 0
    
    @property
    def stdev(self) -> float:
        return statistics.stdev(self.times_ms) if len(self.times_ms) > 1 else 0


def get_image_files(input_dir: str) -> List[Path]:
    """Get list of supported image files in directory."""
    input_path = Path(input_dir)
    if not input_path.is_dir():
        print(f"Error: Input directory does not exist: {input_dir}")
        sys.exit(1)
    
    files = []
    for f in sorted(input_path.iterdir()):
        if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS:
            files.append(f)
    
    return files


def resize_image(img: pyvips.Image, max_size: int) -> pyvips.Image:
    """Resize image so longest edge is max_size, preserving aspect ratio."""
    scale = max_size / max(img.width, img.height)
    if scale >= 1.0:
        return img  # Don't upscale
    return img.resize(scale)


def benchmark_resize(
    image_path: Path,
    output_dir: Path,
    results: dict,
    verbose: bool = False
) -> None:
    """Benchmark resizing a single image to all output sizes and formats."""
    
    # Load image fully into memory (random access needed for multiple operations)
    img = pyvips.Image.new_from_file(str(image_path))
    
    if verbose:
        print(f"  Source: {image_path.name} ({img.width}x{img.height})")
    
    stem = image_path.stem
    
    # Define operations: (name, max_size, quality)
    operations = [
        ("thumbnail", THUMBNAIL_MAX_SIZE, THUMBNAIL_QUALITY),
        ("display", DISPLAY_MAX_SIZE, DISPLAY_QUALITY),
    ]
    
    # Define output formats
    formats = [
        ("jpeg", ".jpg", lambda img, path, q: img.jpegsave(path, Q=q)),
        ("webp", ".webp", lambda img, path, q: img.webpsave(path, Q=q)),
    ]
    
    for op_name, max_size, quality in operations:
        for fmt_name, ext, save_func in formats:
            key = f"{op_name}_{fmt_name}"
            
            # Time the resize and save operation
            start = time.perf_counter()
            
            resized = resize_image(img, max_size)
            output_path = output_dir / f"{stem}_{op_name}{ext}"
            save_func(resized, str(output_path), quality)
            
            elapsed_ms = (time.perf_counter() - start) * 1000
            results[key].times_ms.append(elapsed_ms)
            
            if verbose:
                print(f"    {op_name:10} {fmt_name:5}: {elapsed_ms:8.2f} ms")


def print_results(results: dict) -> None:
    """Print formatted benchmark results."""
    print("\n" + "=" * 70)
    print("BENCHMARK RESULTS")
    print("=" * 70)
    
    print(f"\n{'Operation':<20} {'Format':<8} {'Count':>6} {'Avg (ms)':>12} {'Min (ms)':>12} {'Max (ms)':>12} {'StdDev':>10}")
    print("-" * 70)
    
    for key, result in results.items():
        if result.count > 0:
            print(f"{result.operation:<20} {result.format:<8} {result.count:>6} "
                  f"{result.avg:>12.2f} {result.min:>12.2f} {result.max:>12.2f} {result.stdev:>10.2f}")
    
    print("-" * 70)
    
    # Summary by format
    print("\nSUMMARY BY FORMAT:")
    for fmt in ["jpeg", "webp"]:
        fmt_times = []
        for key, result in results.items():
            if result.format == fmt:
                fmt_times.extend(result.times_ms)
        if fmt_times:
            avg = statistics.mean(fmt_times)
            total = sum(fmt_times)
            print(f"  {fmt.upper():5}: {len(fmt_times)} operations, "
                  f"avg {avg:.2f} ms/op, total {total:.2f} ms")
    
    # Summary by operation
    print("\nSUMMARY BY OPERATION:")
    for op in ["thumbnail", "display"]:
        op_times = []
        for key, result in results.items():
            if result.operation == op:
                op_times.extend(result.times_ms)
        if op_times:
            avg = statistics.mean(op_times)
            total = sum(op_times)
            print(f"  {op.capitalize():10}: {len(op_times)} operations, "
                  f"avg {avg:.2f} ms/op, total {total:.2f} ms")


def main():
    parser = argparse.ArgumentParser(
        description="Profile VIPS image processing library performance.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Resize parameters:
  Display:   {DISPLAY_MAX_SIZE}px max dimension, quality {DISPLAY_QUALITY}
  Thumbnail: {THUMBNAIL_MAX_SIZE}px max dimension, quality {THUMBNAIL_QUALITY}

Output formats: JPEG and WebP

Examples:
  {sys.argv[0]} --input ./sample-data/24mp
  {sys.argv[0]} --input ./sample-data/48mp --output ./results --verbose
        """
    )
    
    parser.add_argument(
        "--input", "-i",
        required=True,
        help="Input directory containing images to process"
    )
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="Output directory for resized images (default: input_dir/output)"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show timing for each individual image"
    )
    parser.add_argument(
        "--keep-output", "-k",
        action="store_true",
        help="Keep output files after benchmarking (default: delete)"
    )
    
    args = parser.parse_args()
    
    # Setup paths
    input_dir = Path(args.input).resolve()
    script_dir = Path(__file__).parent.resolve()
    output_dir = Path(args.output).resolve() if args.output else script_dir / "sample_output"
    
    # Get image files
    image_files = get_image_files(str(input_dir))
    if not image_files:
        print(f"Error: No supported image files found in {input_dir}")
        print(f"Supported formats: {', '.join(SUPPORTED_EXTENSIONS)}")
        sys.exit(1)
    
    print(f"VIPS Image Processing Benchmark")
    print(f"================================")
    print(f"VIPS version: {pyvips.version(0)}.{pyvips.version(1)}.{pyvips.version(2)}")
    print(f"Input directory: {input_dir}")
    print(f"Output directory: {output_dir}")
    print(f"Images to process: {len(image_files)}")
    print(f"\nResize parameters:")
    print(f"  Display:   {DISPLAY_MAX_SIZE}px, quality {DISPLAY_QUALITY}")
    print(f"  Thumbnail: {THUMBNAIL_MAX_SIZE}px, quality {THUMBNAIL_QUALITY}")
    print()
    
    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Initialize results
    results = {
        "thumbnail_jpeg": TimingResult("thumbnail", "jpeg"),
        "thumbnail_webp": TimingResult("thumbnail", "webp"),
        "display_jpeg": TimingResult("display", "jpeg"),
        "display_webp": TimingResult("display", "webp"),
    }
    
    # Process each image
    print("Processing images...")
    total_start = time.perf_counter()
    
    for i, image_path in enumerate(image_files, 1):
        if args.verbose:
            print(f"\n[{i}/{len(image_files)}] {image_path.name}")
        else:
            print(f"  Processing {i}/{len(image_files)}: {image_path.name}...", end=" ", flush=True)
        
        try:
            benchmark_resize(image_path, output_dir, results, args.verbose)
            if not args.verbose:
                print("done")
        except Exception as e:
            print(f"error: {e}")
    
    total_time = time.perf_counter() - total_start
    
    # Print results
    print_results(results)
    
    print(f"\nTotal benchmark time: {total_time:.2f} seconds")
    
    # Cleanup output files unless --keep-output
    if not args.keep_output:
        print("\nCleaning up output files...")
        for f in output_dir.iterdir():
            if f.is_file():
                f.unlink()
        try:
            output_dir.rmdir()
        except OSError:
            pass  # Directory not empty or doesn't exist
    else:
        print(f"\nOutput files kept in: {output_dir}")


if __name__ == "__main__":
    main()
