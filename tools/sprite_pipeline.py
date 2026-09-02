#!/usr/bin/env python3
"""Render deterministic animation sprite sheets.

Examples:
    python3 tools/sprite_pipeline.py --all --out assets/sprites/generated/anim/
    python3 tools/sprite_pipeline.py --input assets/sprites/boss.png \
        --out /tmp/poc/ --frames-dir frames --sheet boss_pulse_sheet.png

``--all`` writes procedural 3/4-view character sheets: player idle/shoot,
enemy walks, and the boss pulse. The explicit input mode remains the
silhouette-based four-frame Boss-Pulse PoC used before Phase 9.
"""

import argparse
import colorsys
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


CANVAS_SIZE = 128
FRAME_COUNT = 4
FRAME_SPECS = (
    (0.0, 1.00, 56, 40),
    (0.60, 1.10, 64, 130),
    (0.85, 2.20, 72, 220),
    (0.35, 1.10, 58, 70),
)
WALK_FRAME_SPECS = (
    (-3.0, -2, 0.85),
    (0.0, 0, 1.00),
    (3.0, -2, 0.85),
    (0.0, 0, 1.00),
)
UNIT_SPECS = {
    "player": {
        "palette": ((200, 160, 110), (32, 160, 224), (192, 224, 224), (20, 90, 130), (14, 60, 90)),
        "body": (26, 20), "leg_rx": 6, "head": (12, 11), "animation": "idle",
    },
    "grunt": {
        "palette": ((200, 160, 110), (160, 96, 32), (120, 70, 22), (90, 55, 18), (60, 38, 12)),
        "body": (26, 20), "leg_rx": 6, "head": (12, 11), "animation": "walk",
    },
    "runner": {
        "palette": ((200, 160, 110), (160, 96, 32), (224, 224, 224), (90, 55, 18), (60, 38, 12)),
        "body": (20, 20), "leg_rx": 6, "head": (12, 11), "animation": "walk",
    },
    "tank": {
        "palette": ((200, 160, 110), (160, 96, 32), (192, 192, 192), (90, 55, 18), (60, 38, 12)),
        "body": (32, 22), "leg_rx": 8, "head": (12, 11), "animation": "walk",
    },
    "boss": {
        "palette": ((200, 160, 110), (160, 32, 160), (96, 0, 96), (110, 20, 110), (70, 12, 70)),
        "body": (34, 26), "leg_rx": 8, "head": (14, 13), "animation": "pulse",
    },
}
SPRITES_DIRECTORY = Path("assets/sprites")


def parse_arguments():
    parser = argparse.ArgumentParser(description="Create deterministic animation sprite sheets.")
    parser.add_argument("--all", action="store_true", help="Render all unit animation sheets.")
    parser.add_argument("--input", type=Path, help="Source sprite for legacy Boss-Pulse mode.")
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--frames-dir", help="Legacy output frames directory.")
    parser.add_argument("--sheet", help="Legacy output sheet filename.")
    arguments = parser.parse_args()
    if not arguments.all and (arguments.input is None or not arguments.frames_dir or not arguments.sheet):
        parser.error("legacy mode requires --input, --frames-dir, and --sheet")
    return arguments


def tint_silhouette(image, violet_mix, brightness):
    rgba = image.convert("RGBA")
    pixels = []
    target_hue = 280 / 360
    for red, green, blue, alpha in rgba.get_flattened_data():
        hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
        hue = hue * (1 - violet_mix) + target_hue * violet_mix
        saturation = min(1.0, saturation * (1 - violet_mix * 0.20) + violet_mix * 0.18)
        value = min(1.0, value * brightness)
        tinted = colorsys.hsv_to_rgb(hue, saturation, value)
        pixels.append(tuple(round(channel * 255) for channel in tinted) + (alpha,))
    result = Image.new("RGBA", rgba.size)
    result.putdata(pixels)
    return result


def create_radial_glow(size, radius, opacity, color, center=None):
    glow = Image.new("RGBA", (size, size))
    center = center or ((size - 1) / 2, (size - 1) / 2)
    pixels = []
    for y in range(size):
        for x in range(size):
            distance = ((x - center[0]) ** 2 + (y - center[1]) ** 2) ** 0.5
            falloff = max(0.0, 1.0 - distance / radius) ** 1.0
            pixels.append((*color, round(opacity * falloff)) if falloff else (0, 0, 0, 0))
    glow.putdata(pixels)
    return glow


def center_on_canvas(image, y_offset=0):
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    x = (CANVAS_SIZE - image.width) // 2
    y = (CANVAS_SIZE - image.height) // 2 + y_offset
    canvas.alpha_composite(image, (x, y))
    return canvas


def render_frame(source, violet_mix, brightness, glow_radius, glow_alpha):
    silhouette = center_on_canvas(tint_silhouette(source, violet_mix, brightness))
    glow_color = (255, 255, 255) if violet_mix == 0 else (190, 112, 255)
    back_glow = create_radial_glow(CANVAS_SIZE, glow_radius, glow_alpha, glow_color)
    front_glow = create_radial_glow(CANVAS_SIZE, glow_radius * 0.72, glow_alpha // 7, glow_color)
    frame = Image.alpha_composite(back_glow, silhouette)
    frame = Image.alpha_composite(frame, front_glow)
    screen_alpha = ImageChops.screen(frame.getchannel("A"), front_glow.getchannel("A"))
    frame.putalpha(screen_alpha)
    return frame


def render_bob_frame(source, is_bobbing):
    if not is_bobbing:
        return center_on_canvas(source)
    scaled_size = tuple(round(dimension * 1.02) for dimension in source.size)
    scaled = source.resize(scaled_size, Image.Resampling.LANCZOS)
    return center_on_canvas(scaled, 2)


def render_shoot_frame(source):
    silhouette = center_on_canvas(tint_silhouette(source, 0.0, 1.25))
    muzzle = create_radial_glow(CANVAS_SIZE, 14, 200, (255, 221, 74), (64, 24))
    return Image.alpha_composite(silhouette, muzzle)


def create_ground_shadow(scale, offset_x=0):
    shadow = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    draw = ImageDraw.Draw(shadow)
    radius_x, radius_y = 23 * scale, 8 * scale
    draw.ellipse((64 + offset_x - radius_x, 108 - radius_y, 64 + offset_x + radius_x, 108 + radius_y), fill=(12, 8, 20, 70))
    return shadow


def render_walk_frame(source, rotation_deg, bob_y, shadow_scale, shadow_offset_x=0):
    shadow = create_ground_shadow(shadow_scale, shadow_offset_x)
    silhouette = center_on_canvas(tint_silhouette(source, 0.0, 1.0))
    rotated = silhouette.rotate(rotation_deg, resample=Image.Resampling.BICUBIC, expand=False)
    shadow.alpha_composite(rotated, (0, bob_y))
    return shadow


def draw_ellipse(draw, center_x, center_y, radius_x, radius_y, color):
    draw.ellipse((center_x - radius_x, center_y - radius_y, center_x + radius_x, center_y + radius_y), fill=color)


def render_character_frame(unit, leg_l, leg_r, tilt, bob, shadow_scale, extra=None, shadow_offset_x=0):
    """Render one deterministic 3/4-view character animation frame."""
    spec = UNIT_SPECS[unit]
    head_color, body_color, detail_color, leg_color, foot_color = spec["palette"]
    center_x, center_y = 64, 58
    frame = create_ground_shadow(shadow_scale, shadow_offset_x)
    legs = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    legs_draw = ImageDraw.Draw(legs)
    for hip_x, length in ((center_x - 9, leg_l), (center_x + 9, leg_r)):
        leg_center_y = center_y + 8 + length / 2
        draw_ellipse(legs_draw, hip_x, leg_center_y, spec["leg_rx"], length / 2, leg_color)
        draw_ellipse(legs_draw, hip_x + 2, center_y + 8 + length + 3, 7, 4, foot_color)
    frame.alpha_composite(legs)

    upper = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    upper_draw = ImageDraw.Draw(upper)
    body_rx, body_ry = spec["body"]
    draw_ellipse(upper_draw, center_x, center_y, body_rx, body_ry, body_color)
    draw_ellipse(upper_draw, center_x, center_y - 2, min(18, body_rx - 4), min(12, body_ry - 4), detail_color)
    head_rx, head_ry = spec["head"]
    draw_ellipse(upper_draw, center_x, center_y - 24, head_rx, head_ry, head_color)
    helmet_color = detail_color if unit == "boss" else body_color
    draw_ellipse(upper_draw, center_x, center_y - 26, 8, 6, helmet_color)
    upper = upper.rotate(tilt, resample=Image.Resampling.BICUBIC, center=(center_x, center_y))
    frame.alpha_composite(upper, (0, bob))

    if extra == "muzzle":
        frame.alpha_composite(create_radial_glow(CANVAS_SIZE, 14, 200, (255, 221, 74), (64, 18)))
    if extra is not None and extra != "muzzle":
        _, _, glow_radius, glow_alpha = extra
        glow = create_radial_glow(CANVAS_SIZE, glow_radius, glow_alpha, (190, 112, 255), (64, 58))
        frame = Image.alpha_composite(glow, frame)
    return frame


def render_unit_frames(unit):
    if unit == "boss":
        leg_lengths = ((20, 16), (16, 20), (20, 16), (16, 20))
        return [render_character_frame(unit, *leg_lengths[index], 0, 0, 1.0, spec) for index, spec in enumerate(FRAME_SPECS)]
    if unit in ("grunt", "runner", "tank"):
        leg_pairs = ((24, 12), (16, 16), (12, 24), (16, 16))
        return [
            render_character_frame(unit, *leg_pairs[index], *spec, shadow_offset_x=1 if index == 3 else 0)
            for index, spec in enumerate(WALK_FRAME_SPECS)
        ]
    frames = [
        render_character_frame(unit, 16, 16, 0, 0, 1.0),
        render_character_frame(unit, 16, 16, 0, -1, 0.95),
    ]
    return frames + [render_character_frame(unit, 16, 16, 0, 0, 1.0, "muzzle")]


def write_outputs(frames, output_directory, frames_directory, sheet_name, frame_prefix="frame"):
    output_directory.mkdir(parents=True, exist_ok=True)
    frames_path = output_directory / frames_directory
    frames_path.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(frames_path / f"{frame_prefix}_{index}.png")
    sheet = Image.new("RGBA", (CANVAS_SIZE * len(frames), CANVAS_SIZE))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * CANVAS_SIZE, 0))
    sheet.save(output_directory / sheet_name)


def render_all(output_directory):
    for unit in UNIT_SPECS:
        frames = render_unit_frames(unit)
        write_outputs(frames, output_directory, "frames", f"{unit}_sheet.png", f"{unit}_frame")
        print(f"Created {len(frames)} {unit} frames and sheet: {output_directory / (unit + '_sheet.png')}")


def main():
    arguments = parse_arguments()
    random.seed(42)
    if arguments.all:
        render_all(arguments.out)
        return
    source = Image.open(arguments.input).convert("RGBA")
    frames = [render_frame(source, *spec) for spec in FRAME_SPECS]
    write_outputs(frames, arguments.out, arguments.frames_dir, arguments.sheet)
    print(f"Created {len(frames)} frames in {arguments.out / arguments.frames_dir}")
    print(f"Created sheet: {arguments.out / arguments.sheet}")


if __name__ == "__main__":
    main()
