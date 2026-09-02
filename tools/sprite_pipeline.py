#!/usr/bin/env python3
"""Render deterministic animation sprite sheets from the static game sprites.

Examples:
    python3 tools/sprite_pipeline.py --all --out assets/sprites/generated/anim/
    python3 tools/sprite_pipeline.py --input assets/sprites/boss.png \
        --out /tmp/poc/ --frames-dir frames --sheet boss_pulse_sheet.png

``--all`` writes player idle/shoot, enemy walk, and boss pulse sheets with
their individual frames. The explicit input mode remains the four-frame
Boss-Pulse PoC used before Phase 9.
"""

import argparse
import colorsys
import random
from pathlib import Path

from PIL import Image, ImageChops


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
    "player": {"input": "player.png", "frame_specs": ("idle", "bob", "shoot"), "animation": "idle"},
    "grunt": {"input": "grunt.png", "frame_specs": WALK_FRAME_SPECS, "animation": "walk"},
    "runner": {"input": "runner.png", "frame_specs": WALK_FRAME_SPECS, "animation": "walk"},
    "tank": {"input": "tank.png", "frame_specs": WALK_FRAME_SPECS, "animation": "walk"},
    "boss": {"input": "boss.png", "frame_specs": FRAME_SPECS, "animation": "pulse"},
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


def create_ground_shadow(width, scale, offset_x=0):
    shadow_width = round(width * 1.25 * scale)
    shadow_height = round(shadow_width * 0.45)
    shadow = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE))
    pixels = []
    center_x = (CANVAS_SIZE - 1) / 2 + offset_x
    center_y = 102
    radius_x = shadow_width / 2
    radius_y = shadow_height / 2
    for y in range(CANVAS_SIZE):
        for x in range(CANVAS_SIZE):
            distance = ((x - center_x) / radius_x) ** 2 + ((y - center_y) / radius_y) ** 2
            opacity = round(70 * max(0.0, 1.0 - distance) ** 1.4)
            pixels.append((12, 8, 20, opacity))
    shadow.putdata(pixels)
    return shadow


def render_walk_frame(source, rotation_deg, bob_y, shadow_scale, shadow_offset_x=0):
    shadow = create_ground_shadow(source.width, shadow_scale, shadow_offset_x)
    silhouette = center_on_canvas(tint_silhouette(source, 0.0, 1.0))
    rotated = silhouette.rotate(rotation_deg, resample=Image.Resampling.BICUBIC, expand=False)
    shadow.alpha_composite(rotated, (0, bob_y))
    return shadow


def render_unit_frames(unit, source):
    if unit == "boss":
        return [render_frame(source, *spec) for spec in FRAME_SPECS]
    if unit in ("grunt", "runner", "tank"):
        return [render_walk_frame(source, *spec, 1 if index == 3 else 0) for index, spec in enumerate(WALK_FRAME_SPECS)]
    frames = [render_bob_frame(source, False), render_bob_frame(source, True)]
    if unit == "player":
        frames.append(render_shoot_frame(source))
    return frames


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
    for unit, spec in UNIT_SPECS.items():
        source = Image.open(SPRITES_DIRECTORY / spec["input"]).convert("RGBA")
        frames = render_unit_frames(unit, source)
        write_outputs(frames, output_directory, "frames", f"{unit}_sheet.png", f"{unit}_frame")
        print(f"Created {len(spec['frame_specs'])} {unit} frames and sheet: {output_directory / (unit + '_sheet.png')}")


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
