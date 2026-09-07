import math
from PIL import Image, ImageDraw

SCALE = 4
SIZE = 512 * SCALE  # 2048

# Color Palette (Aura Quest Kinetic Neo-Brutalist)
PURPLE = (124, 58, 237)          # #7C3AED Kinetic Violet
DEEP_PURPLE = (109, 40, 217)     # #6D28D9
BG_WARM = (253, 239, 231)        # #FDEFE7
GRID_DOT = (230, 208, 195)
INK_BLACK = (25, 25, 25)         # #191919
WHITE = (255, 255, 255)          # #FFFFFF
YELLOW = (255, 199, 0)           # #FFC700 Primary Yellow
PINK = (255, 42, 133)            # #FF2A85 Neon Pink
GREEN = (0, 200, 83)             # #00C853 Mint Green

def draw_sparkle(draw, scx, scy, r, col):
    r_in = r * 0.22
    sp_pts = []
    for i in range(8):
        angle = i * (math.pi / 4)
        dist = r if i % 2 == 0 else r_in
        sp_pts.append((scx + dist * math.cos(angle), scy + dist * math.sin(angle)))
    draw.polygon(sp_pts, fill=col, outline=INK_BLACK, width=2*SCALE)

def draw_die(draw, dx, dy, size, val, bg_col, pip_col):
    r = int(size * 0.22)
    sh = 14 * SCALE
    draw.rounded_rectangle([dx + sh, dy + sh, dx + size + sh, dy + size + sh], radius=r, fill=INK_BLACK)
    draw.rounded_rectangle([dx, dy, dx + size, dy + size], radius=r, fill=bg_col, outline=INK_BLACK, width=10*SCALE)
    pr = int(size * 0.088)
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

def create_icon_variant_a():
    """Variant A: Kinetic Violet background with framed Neo-Brutalist card, 3D Lightning & Die"""
    img = Image.new("RGBA", (SIZE, SIZE), PURPLE)
    draw = ImageDraw.Draw(img)

    # 1. Subtle diagonal stripes
    stripe_w = 42 * SCALE
    for i in range(-SIZE, SIZE * 2, stripe_w * 2):
        draw.polygon([
            (i, 0),
            (i + stripe_w, 0),
            (i + stripe_w + SIZE, SIZE),
            (i + SIZE, SIZE)
        ], fill=DEEP_PURPLE)

    # 2. Central Neo-Brutalist Card
    margin = 52 * SCALE
    bw = SIZE - margin * 2
    bh = SIZE - margin * 2
    bx = margin
    by = margin
    rad = 64 * SCALE
    sh = 24 * SCALE

    # Shadow & Card Fill
    draw.rounded_rectangle([bx + sh, by + sh, bx + bw + sh, by + bh + sh], radius=rad, fill=INK_BLACK)
    draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=rad, fill=BG_WARM, outline=INK_BLACK, width=14*SCALE)

    # 3. 3D Die in top right of card
    die_s = 100 * SCALE
    die_x = bx + bw - die_s - 40 * SCALE
    die_y = by + 40 * SCALE
    draw_die(draw, die_x, die_y, die_s, 5, WHITE, PINK)

    # 4. Central 3D Lightning Bolt
    cx = SIZE // 2 - 18 * SCALE
    cy = SIZE // 2 + 15 * SCALE
    lw = 240 * SCALE
    lh = 320 * SCALE

    pts = [
        (cx + lw * 0.18, cy - lh * 0.50),
        (cx - lw * 0.45, cy + lh * 0.05),
        (cx - lw * 0.05, cy + lh * 0.05),
        (cx - lw * 0.30, cy + lh * 0.50),
        (cx + lw * 0.45, cy - lh * 0.05),
        (cx + lw * 0.05, cy - lh * 0.05),
    ]

    # Shadow offset
    sh_pts = [(x + 20 * SCALE, y + 20 * SCALE) for (x, y) in pts]
    draw.polygon(sh_pts, fill=INK_BLACK)

    # Violet Extrude
    ext_pts = [(x + 10 * SCALE, y + 10 * SCALE) for (x, y) in pts]
    draw.polygon(ext_pts, fill=PURPLE)

    # Main Body with crisp outline
    draw.polygon(pts, fill=YELLOW, outline=INK_BLACK, width=12*SCALE)

    # Highlight line on top-left edge
    h_p1 = (cx + lw * 0.15, cy - lh * 0.45)
    h_p2 = (cx - lw * 0.38, cy + lh * 0.02)
    draw.line([h_p1, h_p2], fill=WHITE, width=6*SCALE)

    # 5. Sparkles
    draw_sparkle(draw, bx + 55 * SCALE, by + bh - 65 * SCALE, 26 * SCALE, PINK)
    draw_sparkle(draw, bx + 65 * SCALE, by + 65 * SCALE, 20 * SCALE, YELLOW)
    draw_sparkle(draw, die_x - 18 * SCALE, die_y + die_s + 18 * SCALE, 16 * SCALE, GREEN)

    return img.resize((512, 512), Image.Resampling.LANCZOS)


def create_icon_variant_c():
    """Variant C: Full Warm #FDEFE7 background with Neo-Brutalist Dot Grid, Giant 3D Lightning & Dual Dice"""
    img = Image.new("RGB", (SIZE, SIZE), BG_WARM)
    draw = ImageDraw.Draw(img)

    # Dot Grid
    dot_spacing = 64 * SCALE
    dot_radius = 4 * SCALE
    for x in range(dot_spacing // 2, SIZE, dot_spacing):
        for y in range(dot_spacing // 2, SIZE, dot_spacing):
            draw.ellipse([x - dot_radius, y - dot_radius, x + dot_radius, y + dot_radius], fill=GRID_DOT)

    # Large 3D Die in upper right (Purple with white pips)
    die_s = 130 * SCALE
    die_x = SIZE - die_s - 65 * SCALE
    die_y = 65 * SCALE
    draw_die(draw, die_x, die_y, die_s, 6, PURPLE, WHITE)

    # Giant Central 3D Lightning Bolt
    cx = SIZE // 2 - 35 * SCALE
    cy = SIZE // 2 + 25 * SCALE
    lw = 300 * SCALE
    lh = 390 * SCALE

    pts = [
        (cx + lw * 0.18, cy - lh * 0.50),
        (cx - lw * 0.45, cy + lh * 0.05),
        (cx - lw * 0.05, cy + lh * 0.05),
        (cx - lw * 0.30, cy + lh * 0.50),
        (cx + lw * 0.45, cy - lh * 0.05),
        (cx + lw * 0.05, cy - lh * 0.05),
    ]

    # Hard 3D Ink Shadow
    sh_pts = [(x + 26 * SCALE, y + 26 * SCALE) for (x, y) in pts]
    draw.polygon(sh_pts, fill=INK_BLACK)

    # Violet Extrude
    ext_pts = [(x + 13 * SCALE, y + 13 * SCALE) for (x, y) in pts]
    draw.polygon(ext_pts, fill=PURPLE)

    # Main Body with thick border
    draw.polygon(pts, fill=YELLOW, outline=INK_BLACK, width=14*SCALE)

    # Inner White Rim-Light Highlight
    h_p1 = (cx + lw * 0.15, cy - lh * 0.45)
    h_p2 = (cx - lw * 0.38, cy + lh * 0.02)
    draw.line([h_p1, h_p2], fill=WHITE, width=7*SCALE)

    # Secondary Die on bottom left (White with pink pips)
    s_die_s = 95 * SCALE
    s_die_x = 65 * SCALE
    s_die_y = SIZE - s_die_s - 75 * SCALE
    draw_die(draw, s_die_x, s_die_y, s_die_s, 5, WHITE, PINK)

    # Sparkles
    draw_sparkle(draw, 90 * SCALE, 110 * SCALE, 30 * SCALE, YELLOW)
    draw_sparkle(draw, SIZE - 85 * SCALE, SIZE - 110 * SCALE, 32 * SCALE, PINK)
    draw_sparkle(draw, cx + lw * 0.42 + 25 * SCALE, cy + 25 * SCALE, 20 * SCALE, GREEN)

    return img.resize((512, 512), Image.Resampling.LANCZOS)


icon_a = create_icon_variant_a()
icon_c = create_icon_variant_c()

# Default primary logo is Variant A (Kinetic Violet with framed card - best on all app store themes)
icon_a.save("d:/vibe projects/Aura 100/deploy/store/assets/icon_512.png", "PNG", optimize=True)
icon_a.save("C:/Users/denis/Desktop/AuraQuest_Store_Bilder/icon_512.png", "PNG", optimize=True)
icon_a.save("C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_variant_a.png", "PNG", optimize=True)

# Also save Variant C (Warm Canvas Edition)
icon_c.save("d:/vibe projects/Aura 100/deploy/store/assets/icon_512_variant_c.png", "PNG", optimize=True)
icon_c.save("C:/Users/denis/Desktop/AuraQuest_Store_Bilder/icon_512_variant_c_warm.png", "PNG", optimize=True)
icon_c.save("C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_variant_c.png", "PNG", optimize=True)

print("Icons successfully refined and saved!")
