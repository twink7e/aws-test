"""Render the repository's assessment architecture as a shareable PNG."""

from __future__ import annotations

from math import atan2, cos, sin
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "architecture.png"
SCALE = 2
WIDTH, HEIGHT = 1800, 1180

BG = "#f6f8fb"
INK = "#15233b"
MUTED = "#50617a"
LINE = "#9aacc3"
BLUE = "#e6f0ff"
BLUE_STROKE = "#5183ce"
GREEN = "#e5f6ef"
GREEN_STROKE = "#429b75"
PURPLE = "#f0eafb"
PURPLE_STROKE = "#8f65c7"
ORANGE = "#fff0df"
ORANGE_STROKE = "#d9943c"


def xy(point: tuple[int, int]) -> tuple[int, int]:
    return point[0] * SCALE, point[1] * SCALE


def rect(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return tuple(value * SCALE for value in box)  # type: ignore[return-value]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = (
        [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "DejaVuSans-Bold.ttf",
        ]
        if bold
        else [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "DejaVuSans.ttf",
        ]
    )
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size * SCALE)
        except OSError:
            continue
    raise RuntimeError("A TrueType font is required to render the architecture diagram")


image = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), BG)
draw = ImageDraw.Draw(image)
title_font = font(40, True)
section_font = font(20, True)
box_title_font = font(25, True)
box_text_font = font(18)


def text_at(point: tuple[int, int], value: str, *, fill=INK, typeface=None) -> None:
    draw.text(xy(point), value, fill=fill, font=typeface or box_text_font)


def box(
    bounds: tuple[int, int, int, int],
    heading: str,
    detail: str,
    *,
    fill: str,
    stroke: str,
) -> None:
    draw.rounded_rectangle(
        rect(bounds), radius=17 * SCALE, fill=fill, outline=stroke, width=3 * SCALE
    )
    x1, y1, _, _ = bounds
    text_at((x1 + 20, y1 + 17), heading, typeface=box_title_font)
    for index, line in enumerate(detail.split("\n")):
        text_at((x1 + 20, y1 + 54 + index * 24), line, fill=MUTED)


def arrow(
    start: tuple[int, int],
    end: tuple[int, int],
    *,
    color=LINE,
    width=4,
) -> None:
    sx, sy = xy(start)
    ex, ey = xy(end)
    draw.line((sx, sy, ex, ey), fill=color, width=width * SCALE)
    angle = atan2(ey - sy, ex - sx)
    length = 15 * SCALE
    wing = 7 * SCALE
    left = (
        ex - length * cos(angle) + wing * sin(angle),
        ey - length * sin(angle) - wing * cos(angle),
    )
    right = (
        ex - length * cos(angle) - wing * sin(angle),
        ey - length * sin(angle) + wing * cos(angle),
    )
    draw.polygon([(ex, ey), left, right], fill=color)


text_at((70, 42), "POPER DevOps assessment  |  AWS Tokyo", typeface=title_font)
text_at(
    (73, 101),
    "Terraform provisions AWS resources; GitHub Actions builds and releases immutable images.",
    fill=MUTED,
)

text_at((72, 156), "RELEASE", typeface=section_font, fill=BLUE_STROKE)
box((70, 190, 330, 305), "GitHub repository", "main push / merge\nsource and workflow", fill=BLUE, stroke=BLUE_STROKE)
box((395, 190, 665, 305), "GitHub Actions", "hosted runner\nDocker build + Terraform", fill=BLUE, stroke=BLUE_STROKE)
box((730, 190, 990, 305), "Amazon ECR", "app, web, backup\nimmutable image digests", fill=BLUE, stroke=BLUE_STROKE)
box((1060, 190, 1370, 305), "Terraform workload", "ECS service and tasks\nalarms and schedules", fill=BLUE, stroke=BLUE_STROKE)
arrow((330, 247), (395, 247), color=BLUE_STROKE)
arrow((665, 247), (730, 247), color=BLUE_STROKE)
arrow((990, 247), (1060, 247), color=BLUE_STROKE)

text_at((72, 370), "WEB REQUEST", typeface=section_font, fill=GREEN_STROKE)
box((70, 415, 290, 535), "Visitor", "HTTP / HTTPS", fill=GREEN, stroke=GREEN_STROKE)
box((355, 415, 575, 535), "ALB", "health checks\naccess logs", fill=GREEN, stroke=GREEN_STROKE)
box((650, 385, 1200, 675), "ECS Fargate service", "one or two tasks on schedule", fill=GREEN, stroke=GREEN_STROKE)
box((680, 488, 830, 620), "Nginx", "HTTP :8080\nJSON access", fill="#ffffff", stroke=GREEN_STROKE)
box((850, 488, 1030, 620), "PHP-FPM", "Laravel 13\nPHP 8.4", fill="#ffffff", stroke=GREEN_STROKE)
box((1050, 488, 1170, 620), "Agent", "AppConfig\npolling", fill="#ffffff", stroke=GREEN_STROKE)
box((1285, 390, 1710, 510), "RDS PostgreSQL", "single instance in private subnets", fill=PURPLE, stroke=PURPLE_STROKE)
box((1285, 555, 1710, 675), "AWS AppConfig", "hosted configuration and release", fill=PURPLE, stroke=PURPLE_STROKE)
arrow((290, 475), (355, 475), color=GREEN_STROKE)
arrow((575, 475), (680, 550), color=GREEN_STROKE)
arrow((830, 555), (850, 555), color=GREEN_STROKE)
arrow((1030, 550), (1050, 550), color=GREEN_STROKE)
arrow((1200, 450), (1285, 450), color=PURPLE_STROKE)
arrow((1285, 615), (1170, 555), color=PURPLE_STROKE)
arrow((860, 305), (860, 385), color=BLUE_STROKE)
arrow((1210, 305), (1210, 385), color=BLUE_STROKE)

text_at((72, 735), "BACKUP AND OBSERVABILITY", typeface=section_font, fill=ORANGE_STROKE)
box((70, 785, 320, 910), "Scheduler", "daily 02:00\nAsia/Tokyo", fill=ORANGE, stroke=ORANGE_STROKE)
box((370, 785, 640, 910), "Lambda controller", "launch ECS task\ncheck launch + STOPPED", fill=ORANGE, stroke=ORANGE_STROKE)
box((690, 785, 980, 910), "Backup task", "pg_dump -Fc\nupload and verify", fill=ORANGE, stroke=ORANGE_STROKE)
box((1030, 785, 1250, 910), "Amazon S3", "daily .dump files\nretention policy", fill=ORANGE, stroke=ORANGE_STROKE)
box((1300, 785, 1710, 910), "CloudWatch", "logs, metric filters, dashboard, alarms", fill=PURPLE, stroke=PURPLE_STROKE)
box((1300, 965, 1710, 1080), "SNS email", "release notices and failure alerts", fill=PURPLE, stroke=PURPLE_STROKE)
arrow((320, 847), (370, 847), color=ORANGE_STROKE)
arrow((640, 847), (690, 847), color=ORANGE_STROKE)
arrow((980, 847), (1030, 847), color=ORANGE_STROKE)
draw.line((xy((835, 910)), xy((835, 955)), xy((505, 955))), fill=ORANGE_STROKE, width=4 * SCALE)
arrow((505, 955), (505, 910), color=ORANGE_STROKE)
text_at((641, 924), "ECS STOPPED event", fill=MUTED)
arrow((980, 806), (1285, 500), color=ORANGE_STROKE)
arrow((1500, 910), (1500, 965), color=PURPLE_STROKE)
arrow((1200, 650), (1300, 785), color=PURPLE_STROKE)

text_at(
    (72, 1122),
    "Cost-first assessment: single-AZ RDS, ALB in two AZs, restricted Fargate ingress, no NAT or standby DB.",
    fill=MUTED,
)

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS).save(OUTPUT)
print(OUTPUT)
