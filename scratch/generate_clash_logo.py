import math
from PIL import Image, ImageDraw

# 2048 x 2048 (4x supersampling)
SCALE = 4
SIZE = 512 * SCALE

# Colors (NO PURPLE/VIOLET!)
CANVAS_BG = (20, 20, 24)        # Deep sleek dark charcoal/obsidian
INK_BLACK = (15, 15, 18)        # #0F0F12
GOLD_YELLOW = (255, 200, 0)     # #FFC800 Electric Gold
LIGHT_YELLOW = (255, 240, 150)
ELECTRIC_BLUE = (0, 160, 255)   # #00A0FF Cyber Clash Blue
LIGHT_BLUE = (180, 230, 255)
WHITE = (255, 255, 255)
ORANGE_RED = (255, 80, 40)      # Energy sparks

def draw_clash_logo():
    img = Image.new("RGBA", (SIZE, SIZE), CANVAS_BG)
    draw = ImageDraw.Draw(img)

    # Subtle radial energy glow behind clash center
    cx, cy = SIZE // 2, SIZE // 2
    for r in range(450 * SCALE, 0, -20 * SCALE):
        alpha = int(40 * (1 - r / (450 * SCALE)))
        # Subtle warm center glow
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(40, 35, 25, alpha))

    # Helper: 4-Point Clash Star
    def draw_sparkle(scx, scy, r, col, outline=None, out_w=0):
        r_in = r * 0.2
        sp_pts = []
        for i in range(8):
            angle = i * (math.pi / 4)
            dist = r if i % 2 == 0 else r_in
            sp_pts.append((scx + dist * math.cos(angle), scy + dist * math.sin(angle)))
        draw.polygon(sp_pts, fill=col, outline=outline, width=out_w)

    # ── BOLT 1: GOLD/YELLOW LIGHTNING (Striking down-right towards center) ──
    # Comes from top-left, meets near center
    bolt1_pts = [
        (cx - 380 * SCALE, cy - 420 * SCALE), # Start top-left
        (cx - 100 * SCALE, cy - 380 * SCALE),
        (cx - 190 * SCALE, cy - 180 * SCALE),
        (cx - 20 * SCALE,  cy - 120 * SCALE), # Mid elbow
        (cx - 120 * SCALE, cy - 10 * SCALE),
        (cx + 40 * SCALE,  cy - 20 * SCALE),  # Clash tip meeting center
        (cx - 180 * SCALE, cy + 80 * SCALE),
        (cx - 110 * SCALE, cy - 70 * SCALE),
        (cx - 280 * SCALE, cy - 10 * SCALE),
        (cx - 210 * SCALE, cy - 200 * SCALE),
        (cx - 360 * SCALE, cy - 160 * SCALE),
    ]

    # ── BOLT 2: ELECTRIC BLUE LIGHTNING (Striking up-left towards center) ──
    # Comes from bottom-right, meets near center
    bolt2_pts = [
        (cx + 380 * SCALE, cy + 420 * SCALE), # Start bottom-right
        (cx + 100 * SCALE, cy + 380 * SCALE),
        (cx + 190 * SCALE, cy + 180 * SCALE),
        (cx + 20 * SCALE,  cy + 120 * SCALE), # Mid elbow
        (cx + 120 * SCALE, cy + 10 * SCALE),
        (cx - 40 * SCALE,  cy + 20 * SCALE),  # Clash tip meeting center
        (cx + 180 * SCALE, cy - 80 * SCALE),
        (cx + 110 * SCALE, cy + 70 * SCALE),
        (cx + 280 * SCALE, cy + 10 * SCALE),
        (cx + 210 * SCALE, cy + 200 * SCALE),
        (cx + 360 * SCALE, cy + 160 * SCALE),
    ]

    # 1. Hard Drop Shadows for both bolts
    sh_x = 22 * SCALE
    sh_y = 22 * SCALE
    b1_shadow = [(x + sh_x, y + sh_y) for (x, y) in bolt1_pts]
    b2_shadow = [(x + sh_x, y + sh_y) for (x, y) in bolt2_pts]
    draw.polygon(b1_shadow, fill=INK_BLACK)
    draw.polygon(b2_shadow, fill=INK_BLACK)

    # 2. Draw Bolt 2 (Electric Blue)
    draw.polygon(bolt2_pts, fill=ELECTRIC_BLUE, outline=INK_BLACK, width=14 * SCALE)
    # Inner light highlight on Bolt 2
    b2_hi = [
        (cx + 340 * SCALE, cy + 380 * SCALE),
        (cx + 120 * SCALE, cy + 350 * SCALE),
        (cx + 190 * SCALE, cy + 190 * SCALE)
    ]
    draw.line(b2_hi, fill=WHITE, width=8 * SCALE, joint="curve")

    # 3. Draw Bolt 1 (Electric Gold/Yellow)
    draw.polygon(bolt1_pts, fill=GOLD_YELLOW, outline=INK_BLACK, width=14 * SCALE)
    # Inner light highlight on Bolt 1
    b1_hi = [
        (cx - 340 * SCALE, cy - 380 * SCALE),
        (cx - 120 * SCALE, cy - 350 * SCALE),
        (cx - 190 * SCALE, cy - 190 * SCALE)
    ]
    draw.line(b1_hi, fill=WHITE, width=8 * SCALE, joint="curve")

    # 4. Central Clash Impact Burst (Where the two bolts collide)
    # Huge clash burst in center
    draw_sparkle(cx, cy, 140 * SCALE, WHITE, outline=INK_BLACK, out_w=8 * SCALE)
    draw_sparkle(cx, cy, 90 * SCALE, GOLD_YELLOW)
    draw_sparkle(cx, cy, 45 * SCALE, WHITE)

    # Sparks & Particles flying off the impact
    draw_sparkle(cx - 90 * SCALE, cy - 70 * SCALE, 32 * SCALE, GOLD_YELLOW)
    draw_sparkle(cx + 90 * SCALE, cy + 70 * SCALE, 32 * SCALE, ELECTRIC_BLUE)
    draw_sparkle(cx + 80 * SCALE, cy - 90 * SCALE, 26 * SCALE, WHITE)
    draw_sparkle(cx - 80 * SCALE, cy + 90 * SCALE, 26 * SCALE, ORANGE_RED)

    # Additional mini sparks
    draw.ellipse([cx - 140 * SCALE, cy + 30 * SCALE, cx - 125 * SCALE, cy + 45 * SCALE], fill=GOLD_YELLOW)
    draw.ellipse([cx + 140 * SCALE, cy - 30 * SCALE, cx + 155 * SCALE, cy - 15 * SCALE], fill=ELECTRIC_BLUE)
    draw.ellipse([cx + 30 * SCALE, cy - 150 * SCALE, cx + 45 * SCALE, cy - 135 * SCALE], fill=WHITE)
    draw.ellipse([cx - 30 * SCALE, cy + 150 * SCALE, cx - 15 * SCALE, cy + 165 * SCALE], fill=GOLD_YELLOW)

    # Downsample to 512 x 512
    return img.resize((512, 512), Image.Resampling.LANCZOS)

icon = draw_clash_logo()

out_path1 = "d:/vibe projects/Aura 100/deploy/store/assets/icon_512.png"
out_path2 = "C:/Users/denis/Desktop/AuraQuest_Store_Bilder/icon_512.png"
out_brain = "C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_clash.png"

icon.save(out_path1, "PNG", optimize=True)
icon.save(out_path2, "PNG", optimize=True)
icon.save(out_brain, "PNG", optimize=True)

print("SUCCESS: Dueling lightning clash logo generated!")
