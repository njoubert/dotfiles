#!/usr/bin/env python3
"""
Generate test images for profiling image processing performance.

Creates sets of images with random color gradients and text overlays
at various megapixel resolutions with 3:2 aspect ratio.
"""

import argparse
import math
import os
import random
import sys

try:
    import numpy as np
    from PIL import Image, ImageDraw, ImageFont
    from scipy.spatial import Delaunay
except ImportError as e:
    print(f"Error: Required library missing. Install with: pip install Pillow numpy scipy")
    print(f"Details: {e}")
    sys.exit(1)

# Preset image sizes (megapixels) and their dimensions at 3:2 aspect ratio
# For 3:2: width = sqrt(MP * 1,000,000 * 3/2), height = width * 2/3
PRESETS = {
    "6mp": (3000, 2000),      # 6,000,000 pixels
    "12mp": (4243, 2829),     # ~12,000,000 pixels
    "24mp": (6000, 4000),     # 24,000,000 pixels
    "48mp": (8485, 5657),     # ~48,000,000 pixels
    "96mp": (12000, 8000),    # 96,000,000 pixels
}

DEFAULT_OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample_input")
DEFAULT_NUM_IMAGES = 10
DEFAULT_JPEG_QUALITY = 95

# Number of triangles scales with image size for consistent detail density
TRIANGLES_PER_MEGAPIXEL = 50


def generate_delaunay_image(width: int, height: int) -> Image.Image:
    """Generate a complex image using Delaunay triangulation with gradient-filled triangles."""
    megapixels = (width * height) / 1_000_000
    num_points = int(TRIANGLES_PER_MEGAPIXEL * megapixels)
    num_points = max(100, min(num_points, 5000))  # Clamp between 100-5000 points
    
    # Generate random points, including corners and edges for full coverage
    points = np.random.rand(num_points, 2)
    points[:, 0] *= width
    points[:, 1] *= height
    
    # Add corner points to ensure full image coverage
    corners = np.array([
        [0, 0], [width, 0], [0, height], [width, height],
        [width/2, 0], [width/2, height], [0, height/2], [width, height/2]
    ])
    points = np.vstack([corners, points])
    
    # Create Delaunay triangulation
    tri = Delaunay(points)
    
    # Create image and draw
    img = Image.new("RGB", (width, height), (128, 128, 128))
    draw = ImageDraw.Draw(img)
    
    # Generate a color palette with smooth transitions
    num_colors = 20
    palette = []
    for _ in range(num_colors):
        palette.append((random.randint(0, 255), random.randint(0, 255), random.randint(0, 255)))
    
    # Draw each triangle with a color based on its centroid position
    for simplex in tri.simplices:
        triangle_points = points[simplex]
        
        # Calculate centroid
        centroid_x = np.mean(triangle_points[:, 0])
        centroid_y = np.mean(triangle_points[:, 1])
        
        # Pick color based on position + randomness for variation
        color_idx = int((centroid_x / width + centroid_y / height) * num_colors / 2) % num_colors
        base_color = palette[color_idx]
        
        # Add per-triangle color variation
        variation = 40
        color = tuple(
            max(0, min(255, c + random.randint(-variation, variation)))
            for c in base_color
        )
        
        # Draw filled triangle
        poly = [(int(p[0]), int(p[1])) for p in triangle_points]
        draw.polygon(poly, fill=color)
    
    return img


def generate_random_gradient(width: int, height: int) -> Image.Image:
    """Generate an image with a random color gradient using NumPy (fast)."""
    # Generate random start and end colors
    start_color = np.array([random.randint(0, 255) for _ in range(3)], dtype=np.float32)
    end_color = np.array([random.randint(0, 255) for _ in range(3)], dtype=np.float32)
    
    # Random gradient direction: 0=horizontal, 1=vertical, 2=diagonal
    direction = random.randint(0, 2)
    
    # Create ratio array using vectorized operations
    if direction == 0:  # Horizontal
        ratio = np.linspace(0, 1, width, dtype=np.float32)
        ratio = np.tile(ratio, (height, 1))  # shape: (height, width)
    elif direction == 1:  # Vertical
        ratio = np.linspace(0, 1, height, dtype=np.float32)
        ratio = np.tile(ratio.reshape(-1, 1), (1, width))  # shape: (height, width)
    else:  # Diagonal
        x_ratio = np.linspace(0, 1, width, dtype=np.float32)
        y_ratio = np.linspace(0, 1, height, dtype=np.float32)
        ratio = (x_ratio[np.newaxis, :] + y_ratio[:, np.newaxis]) / 2
    
    # Interpolate colors: start + (end - start) * ratio
    # Result shape: (height, width, 3)
    pixels = start_color + (end_color - start_color) * ratio[:, :, np.newaxis]
    pixels = np.clip(pixels, 0, 255).astype(np.uint8)
    
    return Image.fromarray(pixels, mode='RGB')


def add_text_overlay(img: Image.Image, image_number: int, resolution_name: str) -> Image.Image:
    """Add text overlay with image number and resolution."""
    draw = ImageDraw.Draw(img)
    width, height = img.size
    
    # Calculate megapixels
    megapixels = (width * height) / 1_000_000
    
    # Text content
    lines = [
        f"Image #{image_number:02d}",
        f"{width} x {height}",
        f"{megapixels:.1f} MP ({resolution_name})",
    ]
    
    # Try to use a reasonable font size based on image dimensions
    font_size = max(20, min(width, height) // 20)
    
    try:
        # Try common system fonts
        font_paths = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                font = ImageFont.truetype(font_path, font_size)
                break
        if font is None:
            font = ImageFont.load_default()
    except Exception:
        font = ImageFont.load_default()
    
    # Calculate text position (center of image)
    text = "\n".join(lines)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (width - text_width) // 2
    y = (height - text_height) // 2
    
    # Draw text shadow for visibility
    shadow_offset = max(2, font_size // 20)
    draw.multiline_text((x + shadow_offset, y + shadow_offset), text, fill=(0, 0, 0), font=font, align="center")
    
    # Draw main text
    draw.multiline_text((x, y), text, fill=(255, 255, 255), font=font, align="center")
    
    return img


def generate_images(preset: str, output_dir: str, num_images: int, quality: int) -> None:
    """Generate a set of test images for a given preset."""
    if preset not in PRESETS:
        print(f"Error: Unknown preset '{preset}'. Available: {', '.join(PRESETS.keys())}")
        sys.exit(1)
    
    width, height = PRESETS[preset]
    preset_dir = os.path.join(output_dir, preset)
    os.makedirs(preset_dir, exist_ok=True)
    
    print(f"Generating {num_images} images at {width}x{height} ({preset})...")
    print(f"Output directory: {preset_dir}")
    
    for i in range(1, num_images + 1):
        print(f"  Generating image {i}/{num_images}...", end=" ", flush=True)
        
        # Generate complex Delaunay triangulation image
        img = generate_delaunay_image(width, height)
        
        # Add text overlay
        img = add_text_overlay(img, i, preset)
        
        # Save as JPEG
        filename = f"test_{preset}_{i:02d}.jpg"
        filepath = os.path.join(preset_dir, filename)
        img.save(filepath, "JPEG", quality=quality)
        
        file_size = os.path.getsize(filepath) / (1024 * 1024)
        print(f"saved {filename} ({file_size:.1f} MB)")
    
    print(f"Done! Generated {num_images} images in {preset_dir}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate test images for profiling image processing performance.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Available presets (all 3:2 aspect ratio):
  6mp   - {PRESETS['6mp'][0]} x {PRESETS['6mp'][1]} pixels
  12mp  - {PRESETS['12mp'][0]} x {PRESETS['12mp'][1]} pixels
  24mp  - {PRESETS['24mp'][0]} x {PRESETS['24mp'][1]} pixels
  48mp  - {PRESETS['48mp'][0]} x {PRESETS['48mp'][1]} pixels
  96mp  - {PRESETS['96mp'][0]} x {PRESETS['96mp'][1]} pixels

Examples:
  {sys.argv[0]} --preset 24mp
  {sys.argv[0]} --preset 48mp --num 5 --quality 90
  {sys.argv[0]} --preset all
        """
    )
    
    parser.add_argument(
        "--preset", "-p",
        choices=list(PRESETS.keys()) + ["all"],
        required=True,
        help="Image size preset to generate (or 'all' for all presets)"
    )
    parser.add_argument(
        "--output", "-o",
        default=DEFAULT_OUTPUT_DIR,
        help=f"Output directory (default: {DEFAULT_OUTPUT_DIR})"
    )
    parser.add_argument(
        "--num", "-n",
        type=int,
        default=DEFAULT_NUM_IMAGES,
        help=f"Number of images to generate (default: {DEFAULT_NUM_IMAGES})"
    )
    parser.add_argument(
        "--quality", "-q",
        type=int,
        default=DEFAULT_JPEG_QUALITY,
        help=f"JPEG quality 1-100 (default: {DEFAULT_JPEG_QUALITY})"
    )
    
    args = parser.parse_args()
    
    # Validate quality
    if not 1 <= args.quality <= 100:
        print("Error: Quality must be between 1 and 100")
        sys.exit(1)
    
    # Create output directory
    os.makedirs(args.output, exist_ok=True)
    
    # Generate images
    if args.preset == "all":
        for preset in PRESETS.keys():
            generate_images(preset, args.output, args.num, args.quality)
            print()
    else:
        generate_images(args.preset, args.output, args.num, args.quality)


if __name__ == "__main__":
    main()
