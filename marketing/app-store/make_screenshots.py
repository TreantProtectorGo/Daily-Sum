#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
TARGET_SIZE = (1284, 2778)

FONT_BOLD = "/System/Library/Fonts/SFNS.ttf"
FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_CJK_CANDIDATES = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/PingFangHK.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
]

ACCENTS = {
    "01-dashboard": (0, 132, 118),
    "02-transactions": (197, 75, 64),
    "03-reports": (35, 157, 94),
    "04-budgets": (193, 133, 30),
    "05-settings": (30, 117, 151),
}

LOCALES = {
    "en": {
        "raw_dir": "raw-screenshots",
        "out_dir": "screenshots",
        "headline_size": 86,
        "subtitle_size": 31,
        "font": FONT_BOLD,
        "screens": {
            "01-dashboard": {
                "output": "01-see-where-your-money-goes.png",
                "headline": "See where your\nmoney goes",
                "subtitle": "Track balances, spending, and recent activity in one calm view.",
            },
            "02-transactions": {
                "output": "02-track-spending-clearly.png",
                "headline": "Track spending\nclearly",
                "subtitle": "Log income and expenses with categories that stay easy to scan.",
            },
            "03-reports": {
                "output": "03-understand-your-month.png",
                "headline": "Understand\nyour month",
                "subtitle": "Review trends and cash flow without unnecessary complexity.",
            },
            "04-budgets": {
                "output": "04-plan-budgets-without-clutter.png",
                "headline": "Plan budgets\nwithout clutter",
                "subtitle": "Keep an eye on spending limits before the month gets away.",
            },
            "05-settings": {
                "output": "05-sync-privately-with-icloud.png",
                "headline": "Sync privately\nwith iCloud",
                "subtitle": "No separate account. Optional iCloud sync keeps data with you.",
            },
        },
    },
    "zh-Hans": {
        "raw_dir": "raw-screenshots-zh-Hans",
        "out_dir": "screenshots-zh-Hans",
        "headline_size": 90,
        "subtitle_size": 32,
        "font": FONT_CJK_CANDIDATES,
        "screens": {
            "01-dashboard": {
                "output": "01-see-where-your-money-goes.png",
                "headline": "看清钱\n花在哪",
                "subtitle": "余额、支出、近期记录，一眼掌握。",
            },
            "02-transactions": {
                "output": "02-track-spending-clearly.png",
                "headline": "每一笔\n都记清",
                "subtitle": "收入、支出、分类清楚，日常记账更轻松。",
            },
            "03-reports": {
                "output": "03-understand-your-month.png",
                "headline": "每月收支\n一目了然",
                "subtitle": "趋势、现金流，用报表看得更清。",
            },
            "04-budgets": {
                "output": "04-plan-budgets-without-clutter.png",
                "headline": "预算进度\n随时看",
                "subtitle": "支出快到上限，及早心中有数。",
            },
            "05-settings": {
                "output": "05-sync-privately-with-icloud.png",
                "headline": "iCloud\n同步",
                "subtitle": "无需另开账户，数据由你的 iCloud 同步。",
            },
        },
    },
    "zh-Hant": {
        "raw_dir": "raw-screenshots-zh-Hant",
        "out_dir": "screenshots-zh-Hant",
        "headline_size": 90,
        "subtitle_size": 32,
        "font": FONT_CJK_CANDIDATES,
        "screens": {
            "01-dashboard": {
                "output": "01-see-where-your-money-goes.png",
                "headline": "看清錢\n花在哪裏",
                "subtitle": "結餘、開支、近期紀錄，一眼掌握。",
            },
            "02-transactions": {
                "output": "02-track-spending-clearly.png",
                "headline": "每一筆\n都記清",
                "subtitle": "收入、開支、分類清楚，日常記帳更輕鬆。",
            },
            "03-reports": {
                "output": "03-understand-your-month.png",
                "headline": "每月收支\n一目了然",
                "subtitle": "趨勢、現金流，用報表看得更清。",
            },
            "04-budgets": {
                "output": "04-plan-budgets-without-clutter.png",
                "headline": "預算進度\n隨時看",
                "subtitle": "開支快將超額，及早心中有數。",
            },
            "05-settings": {
                "output": "05-sync-privately-with-icloud.png",
                "headline": "iCloud\n同步",
                "subtitle": "毋須另開帳戶，資料由你的 iCloud 同步。",
            },
        },
    },
}


def load_font(path: str | list[str], size: int) -> ImageFont.FreeTypeFont:
    paths = path if isinstance(path, list) else [path]
    for candidate in paths:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.truetype(FONT_REGULAR, size=size)


def rounded_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def draw_multiline_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    line_spacing: int,
) -> None:
    x, y = xy
    for line in text.splitlines():
        draw.text((x, y), line, font=font, fill=fill)
        bbox = draw.textbbox((x, y), line, font=font)
        y += (bbox[3] - bbox[1]) + line_spacing


def blend(
    color: tuple[int, int, int],
    background: tuple[int, int, int],
    amount: float,
) -> tuple[int, int, int]:
    return tuple(round(color[i] * amount + background[i] * (1 - amount)) for i in range(3))


def draw_design_system_background(
    canvas: Image.Image,
    key: str,
) -> Image.Image:
    base = (247, 248, 244)
    accent = ACCENTS[key]
    draw = ImageDraw.Draw(canvas)

    # Quiet ledger lines: enough structure to feel financial, not decorative.
    line_color = blend(accent, base, 0.12)
    for x in range(80, TARGET_SIZE[0] - 40, 116):
        draw.line((x, 0, x - 170, 452), fill=line_color, width=1)
    for y in (122, 174, 226, 278):
        draw.line((78, y, TARGET_SIZE[0] - 78, y), fill=(226, 230, 228), width=1)

    wash = Image.new("RGBA", TARGET_SIZE, (255, 255, 255, 0))
    wash_draw = ImageDraw.Draw(wash)
    wash_draw.ellipse((-330, 420, 540, 1280), fill=(*blend(accent, base, 0.42), 34))
    wash_draw.ellipse((760, -300, 1620, 720), fill=(96, 140, 178, 32))

    curve = Image.new("RGBA", TARGET_SIZE, (255, 255, 255, 0))
    curve_draw = ImageDraw.Draw(curve)
    curve_points = [
        (70, 332),
        (250, 300),
        (420, 330),
        (610, 248),
        (820, 276),
        (1030, 206),
        (1210, 222),
    ]
    curve_draw.line(curve_points, fill=(*accent, 52), width=5, joint="curve")
    for point in curve_points[1::2]:
        x, y = point
        curve_draw.ellipse((x - 8, y - 8, x + 8, y + 8), fill=(*accent, 72))

    canvas = Image.alpha_composite(canvas.convert("RGBA"), wash)
    canvas = Image.alpha_composite(canvas, curve)
    return canvas.convert("RGB")


def source_map(raw_dir: Path) -> dict[str, Path]:
    manifest_path = raw_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    files: dict[str, Path] = {}
    for entry in manifest:
        for attachment in entry["attachments"]:
            suggested = attachment["suggestedHumanReadableName"]
            key = suggested.split("_", 1)[0]
            files[key] = raw_dir / attachment["exportedFileName"]
    return files


def make_screen(
    key: str,
    src: Path,
    spec: dict[str, str],
    out_dir: Path,
    font_path: str,
    headline_size: int,
    subtitle_size: int,
) -> None:
    canvas = Image.new("RGB", TARGET_SIZE, (247, 248, 244))
    canvas = draw_design_system_background(canvas, key)
    draw = ImageDraw.Draw(canvas)
    accent = ACCENTS[key]

    headline_font = load_font(font_path, headline_size)
    subtitle_font = load_font(font_path if isinstance(font_path, list) else FONT_REGULAR, subtitle_size)

    draw.rounded_rectangle(
        (78, 54, 152, 64),
        radius=5,
        fill=accent,
    )

    draw_multiline_text(
        draw,
        (78, 82),
        spec["headline"],
        headline_font,
        (16, 22, 28),
        line_spacing=2,
    )
    draw.text((82, 284), spec["subtitle"], font=subtitle_font, fill=(72, 83, 91))

    raw = Image.open(src).convert("RGB")
    phone_width = 1148
    phone_height = round(raw.height * phone_width / raw.width)
    phone = raw.resize((phone_width, phone_height), Image.Resampling.LANCZOS)

    x = (TARGET_SIZE[0] - phone_width) // 2
    y = 382

    shadow = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (x - 8, y + 16, x + phone_width + 8, y + phone_height + 18),
        radius=64,
        fill=(20, 24, 31, 34),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)

    phone_rgba = phone.convert("RGBA")
    mask = rounded_rect_mask(phone.size, radius=52)
    canvas.paste(phone_rgba, (x, y), mask)

    border = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        (x, y, x + phone_width, y + phone_height),
        radius=54,
        outline=(216, 221, 221, 190),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, border).convert("RGB")

    out = out_dir / spec["output"]
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, "PNG", optimize=True)
    print(f"{out.name}: {canvas.size[0]}x{canvas.size[1]}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locale", choices=sorted(LOCALES), default="en")
    args = parser.parse_args()

    locale = LOCALES[args.locale]
    raw_dir = ROOT / locale["raw_dir"]
    out_dir = ROOT / locale["out_dir"]
    screens = locale["screens"]

    files = source_map(raw_dir)
    missing = sorted(set(screens) - set(files))
    if missing:
        raise SystemExit(f"Missing raw screenshots: {', '.join(missing)}")
    out_dir.mkdir(parents=True, exist_ok=True)
    for key, spec in screens.items():
        make_screen(
            key,
            files[key],
            spec,
            out_dir,
            locale["font"],
            locale["headline_size"],
            locale["subtitle_size"],
        )


if __name__ == "__main__":
    main()
