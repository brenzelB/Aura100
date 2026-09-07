import math
from PIL import Image, ImageDraw, ImageFont

SCALE = 4
SIZE = 512 * SCALE  # 2048

# Colors
PURPLE = (124, 58, 237)          # #7C3AED Kinetic Violet
BG_WARM = (253, 239, 231)        # #FDEFE7 App Canvas
GRID_DOT = (230, 208, 195)
INK_BLACK = (25, 25, 25)         # #191919
WHITE = (255, 255, 255)          # #FFFFFF
YELLOW = (255, 199, 0)           # #FFC700 Primary Accent
PINK = (255, 42, 133)            # #FF2A85 Neon Pink
GREEN = (0, 200, 83)             # #00C853 Mint Green

def draw_sparkle(draw, scx, scy, r, col):
    r_in = r * 0.22
    sp_pts = []
    for i in range(8):
        angle = i * (math.pi / 4)
        dist = r if i % 2 == 0 else r_in
        sp_pts.append((scx + dist * math.cos(angle), scy + dist * math.sin(angle)))
    draw.polygon(sp_pts, fill=col, outline=INK_BLACK)

def draw_die(draw, dx, dy, size, val, bg_col, pip_col):
    r = int(size * 0.22)
    sh = 16 * SCALE
    draw.rounded_rectangle([dx + sh, dy + sh, dx + size + sh, dy + size + sh], radius=r, fill=INK_BLACK)
    draw.rounded_rectangle([dx, dy, dx + size, dy + size], radius=r, fill=bg_col, outline=INK_BLACK, width=12*SCALE)
    pr = int(size * 0.09)
    c = size // 2
    l = int(size * 0.28)
    rt = size - l
    coords = {
        1: [(c, c)],
        2: [(l, l), (rt, rt)],
        3: [(l, l), (c, c), (rt, rt)],
        4: [(l, l), (rt, l), (l, rt), (rt, rt)],
        5: [(l, l), (rt, l), (c, c), (l, rt), (rt, rt)],
        6: [(l, l), (rt, l), (l, c), (rt, c), (l, rt), (rt, rt)]
    }
    for px, py in coords.get(val, []):
        draw.ellipse([dx + px - pr, dy + py - pr, dx + px + pr, dy + py + pr], fill=pip_col)

def create_icon_variant_c():
    """Variant C: Full Warm #FDEFE7 background with Neo-Brutalist Grid, Giant 3D Lightning & Dice"""
    img = Image.new("RGB", (SIZE, SIZE), BG_WARM)
    draw = ImageDraw.Draw(img)

    # Dot Grid
    dot_spacing = 64 * SCALE
    dot_radius = 4 * SCALE
    for x in range(dot_spacing // 2, SIZE, dot_spacing):
        for y in range(dot_spacing // 2, SIZE, dot_spacing):
            draw.ellipse([x - dot_radius, y - dot_radius, x + dot_radius, y + dot_radius], fill=GRID_DOT)

    # Large 3D Neo-Brutalist Dice in upper right
    die_s = 130 * SCALE
    die_x = SIZE - die_s - 70 * SCALE
    die_y = 65 * SCALE
    draw_die(draw, die_x, die_y, die_s, 6, PURPLE, WHITE)

    # Giant Central 3D Lightning Bolt
    cx = SIZE // 2 - 35 * SCALE
    cy = SIZE // 2 + 30 * SCALE
    bw = 310 * SCALE
    bh = 400 * SCALE

    pts = [
        (cx + bw * 0.18, cy - bh * 0.50),
        (cx - bw * 0.45, cy + bh * 0.05),
        (cx - bw * 0.05, cy + bh * 0.05),
        (cx - bw * 0.30, cy + bh * 0.50),
        (cx + bw * 0.45, cy - bh * 0.05),
        (cx + bw * 0.05, cy - bh * 0.05),
    ]

    # Deep 3D Shadow (Hard Offset Ink Black)
    sh_x = 28 * SCALE
    sh_y = 28 * SCALE
    pts_sh = [(x + sh_x, y + sh_y) for (x, y) in pts]
    draw.polygon(pts_sh, fill=INK_BLACK)

    # Kinetic Violet 3D Extrude layer
    ext_x = 14 * SCALE
    ext_y = 14 * SCALE
    pts_ext = [(x + ext_x, y + ext_y) for (x, y) in pts]
    draw.polygon(pts_ext, fill=PURPLE)

    # Main Electric Yellow Body
    draw.polygon(pts, fill=YELLOW)

    # Thick Ink Outline
    for i in range(len(pts)):
        p1 = pts[i]
        p2 = pts[(i + 1) % len(pts)]
        draw.line([p1, p2], fill=INK_BLACK, width=16*SCALE)

    # Inner White Rim-Light Highlight
    h_p1 = (cx + bw * 0.15, cy - bh * 0.45)
    h_p2 = (cx - bw * 0.38, cy + bh * 0.02)
    draw.line([h_p1, h_p2], fill=WHITE, width=8*SCALE)

    # Secondary Mini Die on bottom left
    s_die_s = 90 * SCALE
    s_die_x = 65 * SCALE
    s_die_y = SIZE - s_die_s - 85 * SCALE
    draw_die(draw, s_die_x, s_die_y, s_die_s, 5, WHITE, PINK)

    # Sparkles
    draw_sparkle(draw, 90 * SCALE, 110 * SCALE, 32 * SCALE, YELLOW)
    draw_sparkle(draw, SIZE - 90 * SCALE, SIZE - 120 * SCALE, 36 * SCALE, PINK)
    draw_sparkle(draw, cx + bw * 0.45 + 30 * SCALE, cy + 30 * SCALE, 22 * SCALE, GREEN)

    return img.resize((512, 512), Image.Resampling.LANCZOS)

icon_c = create_icon_variant_c()
icon_c.save("d:/vibe projects/Aura 100/deploy/store/assets/icon_512_variant_c.png", "PNG", optimize=True)
icon_c.save("C:/Users/denis/Desktop/AuraQuest_Store_Bilder/icon_512_variant_c.png", "PNG", optimize=True)
icon_c.save("C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_variant_c.png", "PNG", optimize=True)

print("Variant C generated successfully!")
