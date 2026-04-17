from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


SIZES = [16, 32, 128, 256, 512]


def _gradient_background(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(72 + (116 - 72) * t)
        g = int(145 + (198 - 145) * t)
        b = int(255 - (255 - 245) * t)
        for x in range(size):
            pixels[x, y] = (r, g, b, 255)
    return image


def _draw_icon(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    outer = int(size * 0.08)
    radius = int(size * 0.225)
    shadow_draw.rounded_rectangle(
        [outer, outer + int(size * 0.03), size - outer, size - outer + int(size * 0.03)],
        radius=radius,
        fill=(10, 30, 80, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(2, size // 40)))
    canvas.alpha_composite(shadow)

    background = _gradient_background(size)
    bg_mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(bg_mask)
    mask_draw.rounded_rectangle(
        [outer, outer, size - outer, size - outer],
        radius=radius,
        fill=255,
    )
    background.putalpha(bg_mask)
    canvas.alpha_composite(background)

    draw = ImageDraw.Draw(canvas)

    # soft highlight
    draw.ellipse(
        [int(size * 0.14), int(size * 0.08), int(size * 0.72), int(size * 0.44)],
        fill=(255, 255, 255, 42),
    )

    bag_left = int(size * 0.24)
    bag_top = int(size * 0.28)
    bag_right = int(size * 0.76)
    bag_bottom = int(size * 0.74)
    bag_radius = int(size * 0.12)

    draw.rounded_rectangle(
        [bag_left, bag_top, bag_right, bag_bottom],
        radius=bag_radius,
        fill=(255, 255, 255, 245),
    )

    handle_w = int(size * 0.22)
    handle_h = int(size * 0.09)
    handle_left = (size - handle_w) // 2
    handle_top = int(size * 0.19)
    handle_right = handle_left + handle_w
    handle_bottom = handle_top + handle_h

    draw.rounded_rectangle(
        [handle_left, handle_top, handle_right, handle_bottom],
        radius=int(size * 0.05),
        outline=(255, 255, 255, 245),
        width=max(2, size // 32),
    )

    cross_w = int(size * 0.09)
    cross_h = int(size * 0.26)
    cx = size // 2
    cy = int(size * 0.5)
    color = (74, 145, 255, 255)
    draw.rounded_rectangle(
        [cx - cross_w // 2, cy - cross_h // 2, cx + cross_w // 2, cy + cross_h // 2],
        radius=int(size * 0.03),
        fill=color,
    )
    draw.rounded_rectangle(
        [cx - cross_h // 2, cy - cross_w // 2, cx + cross_h // 2, cy + cross_w // 2],
        radius=int(size * 0.03),
        fill=color,
    )

    return canvas


def generate_iconset(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    master = _draw_icon(1024)
    master.save(output_dir / "icon_512x512@2x.png")

    for size in SIZES:
        one_x = master.resize((size, size), Image.Resampling.LANCZOS)
        two_x = master.resize((size * 2, size * 2), Image.Resampling.LANCZOS)
        one_x.save(output_dir / f"icon_{size}x{size}.png")
        two_x.save(output_dir / f"icon_{size}x{size}@2x.png")


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    output_dir = repo_root / "apps" / "mac" / "mac-app" / "AppIcon.iconset"
    generate_iconset(output_dir)
    print(output_dir)


if __name__ == "__main__":
    main()
