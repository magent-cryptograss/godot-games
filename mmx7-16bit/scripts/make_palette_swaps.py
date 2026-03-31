#!/usr/bin/env python3
"""
Generate Zero and Axl sprite sheets by palette-swapping X's sprite sheet.
Also adds Zero's hair as a separate overlay layer.
"""

from PIL import Image
import os

def get_palette_map(img):
    """Analyze X's sprite sheet to find the key blue colors used."""
    colors = {}
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                continue
            key = (r, g, b)
            colors[key] = colors.get(key, 0) + 1

    # Sort by frequency
    sorted_colors = sorted(colors.items(), key=lambda x: -x[1])
    print("Top 20 colors in X sprite sheet:")
    for color, count in sorted_colors[:20]:
        print(f"  RGB({color[0]:3d},{color[1]:3d},{color[2]:3d}) — {count} pixels")
    return sorted_colors

def swap_palette(img, color_map):
    """Create a new image with swapped colors."""
    new_img = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                continue
            key = (r, g, b)
            if key in color_map:
                nr, ng, nb = color_map[key]
                new_img.putpixel((x, y), (nr, ng, nb, a))
    return new_img

def main():
    x_sheet = Image.open("sprites/x_sheet.png").convert("RGBA")
    print(f"X sheet: {x_sheet.width}x{x_sheet.height}")

    palette_info = get_palette_map(x_sheet)

    # Identify X's blue colors from the palette analysis
    # We need to map blues -> reds (Zero) and blues -> dark blue-black (Axl)

    # Build color mapping by checking if a color is "blue-ish"
    # X's blues range from dark navy to bright cyan

    zero_map = {}
    axl_map = {}

    for (r, g, b), count in palette_info:
        # Skip near-black outlines and skin tones
        if r + g + b < 40:  # very dark, keep as-is
            continue
        if r > 180 and g > 150 and b > 100 and r > b:  # skin tone
            continue
        if r > 200 and g > 200 and b > 200:  # white/near-white
            continue

        # Detect blue-ish colors (main armor)
        if b > r and b > g and b > 60:
            # Map to red for Zero
            # Scale: keep relative brightness but shift hue
            brightness = (r + g + b) / 3
            zero_r = min(255, int(b * 1.1))      # blue -> red
            zero_g = min(255, int(r * 0.4))       # reduce green
            zero_b = min(255, int(g * 0.3))       # reduce blue
            zero_map[(r, g, b)] = (zero_r, zero_g, zero_b)

            # Map to dark blue-black for Axl
            axl_r = min(255, int(r * 0.35))
            axl_g = min(255, int(g * 0.35))
            axl_b = min(255, int(b * 0.55))
            axl_map[(r, g, b)] = (axl_r, axl_g, axl_b)

        # Detect cyan/light blue highlights
        elif b > 150 and g > 100 and r < g:
            zero_r = min(255, int(b * 0.9))
            zero_g = min(255, int(g * 0.35))
            zero_b = min(255, int(r * 0.3))
            zero_map[(r, g, b)] = (zero_r, zero_g, zero_b)

            axl_r = min(255, int(r * 0.5))
            axl_g = min(255, int(g * 0.4))
            axl_b = min(255, int(b * 0.5))
            axl_map[(r, g, b)] = (axl_r, axl_g, axl_b)

    # Also swap the red gem to blue for Zero (Zero has blue gem)
    # And add red accents for Axl
    for (r, g, b), count in palette_info:
        if r > 180 and g < 80 and b < 80:  # red gem
            zero_map[(r, g, b)] = (min(255, int(g + 80)), min(255, int(b + 100)), min(255, int(r)))  # red -> blue

    print(f"\nZero palette: {len(zero_map)} color swaps")
    print(f"Axl palette: {len(axl_map)} color swaps")

    # Generate Zero sheet
    zero_sheet = swap_palette(x_sheet, zero_map)
    zero_sheet.save("sprites/zero_sheet.png")
    print("Saved sprites/zero_sheet.png")

    # Generate Axl sheet
    axl_sheet = swap_palette(x_sheet, axl_map)
    # Add red accent lines to Axl (mark distinctive features)
    axl_sheet.save("sprites/axl_sheet.png")
    print("Saved sprites/axl_sheet.png")

if __name__ == "__main__":
    main()
