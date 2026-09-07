import math
from PIL import Image, ImageDraw

SCALE = 4
SIZE = 512 * SCALE

# Background: Clean dark obsidian charcoal
BG_COLOR = (22, 22, 26)         # #16161A
INK_BLACK = (10, 10, 12)        # #0A0A0C
GOLD_YELLOW = (255, 200, 0)     # #FFC800 Primary
LIGHT_GOLD = (255, 235, 120)
CYBER_BLUE = (0, 150, 255)      # #0096FF Rival Blue
LIGHT_BLUE = (150, 220, 255)
WHITE = (255, 255, 255)
ORANGE_SPARK = (255, 90, 40)

def rotate_pt(x, y, angle_rad):
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    return (x * cos_a - y * sin_a, x * sin_a + y * cos_a)

def get_bold_bolt(cx, cy, length, width, angle_deg):
    angle_rad = math.radians(angle_deg)
    
    # Chunky, iconic, powerful 6-point lightning bolt
    raw_pts = [
        (0.0, -0.48 * length),              # Sharp head
        (-0.42 * width, -0.04 * length),    # Outer left corner
        (-0.10 * width, -0.04 * length),    # Inner left crook
        (0.02 * width, 0.48 * length),      # Sharp tail
        (0.42 * width, 0.04 * length),      # Outer right corner
        (0.10 * width, 0.04 * length),      # Inner right crook
    ]
    
    pts = []
    for rx, ry in raw_pts:
        rot_x, rot_y = rotate_pt(rx, ry, angle_rad)
        pts.append((cx + rot_x, cy + rot_y))
    return pts

def draw_sparkle(draw, scx, scy, r, col, outline=None, out_w=0):
    r_in = r * 0.22
    sp_pts = []
    for i in range(8):
        angle = i * (math.pi / 4)
        dist = r if i % 2 == 0 else r_in
        sp_pts.append((scx + dist * math.cos(angle), scy + dist * math.sin(angle)))
    draw.polygon(sp_pts, fill=col, outline=outline, width=out_w)

img = Image.new("RGB", (SIZE, SIZE), BG_COLOR)
draw = ImageDraw.Draw(img)

cx = SIZE // 2
cy = SIZE // 2

# Subtle central impact ambient glow
for r in range(400 * SCALE, 0, -25 * SCALE):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(32, 30, 38))

bolt_len = 390 * SCALE
bolt_w = 200 * SCALE

# Bolt 1: Golden Yellow, angled at 32 degrees (from top-left down to bottom-right)
bolt1_pts = get_bold_bolt(cx, cy, bolt_len, bolt_w, 32)

# Bolt 2: Cyber Blue, angled at -32 degrees (from top-right down to bottom-left)
bolt2_pts = get_bold_bolt(cx, cy, bolt_len, bolt_w, -32)

# 1. Hard Drop Shadows (Offset down-right)
sh_x = 20 * SCALE
sh_y = 20 * SCALE
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt2_pts], fill=INK_BLACK)
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt1_pts], fill=INK_BLACK)

# 2. Draw Bolt 2 (Blue) - Underneath
draw.polygon(bolt2_pts, fill=CYBER_BLUE, outline=INK_BLACK, width=14 * SCALE)
# Blue inner highlight
draw.polygon(get_bold_bolt(cx - 3*SCALE, cy - 3*SCALE, bolt_len * 0.82, bolt_w * 0.52, -32), fill=LIGHT_BLUE)

# 3. Draw Bolt 1 (Yellow) - On top
draw.polygon(bolt1_pts, fill=GOLD_YELLOW, outline=INK_BLACK, width=14 * SCALE)
# Yellow inner highlight
draw.polygon(get_bold_bolt(cx - 3*SCALE, cy - 3*SCALE, bolt_len * 0.82, bolt_w * 0.52, 32), fill=LIGHT_GOLD)

# 4. Central Epic Clash Star (Where they cross)
draw_sparkle(draw, cx, cy, 95 * SCALE, WHITE, outline=INK_BLACK, out_w=8 * SCALE)
draw_sparkle(draw, cx, cy, 60 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx, cy, 28 * SCALE, WHITE)

# Energy clash sparks radiating out
draw_sparkle(draw, cx - 110 * SCALE, cy, 24 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx + 110 * SCALE, cy, 24 * SCALE, CYBER_BLUE)
draw_sparkle(draw, cx, cy - 110 * SCALE, 20 * SCALE, WHITE)
draw_sparkle(draw, cx, cy + 110 * SCALE, 20 * SCALE, ORANGE_SPARK)

# Floating corner micro-sparks
draw_sparkle(draw, 80 * SCALE, 100 * SCALE, 26 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, SIZE - 80 * SCALE, 100 * SCALE, 26 * SCALE, CYBER_BLUE)
draw_sparkle(draw, 90 * SCALE, SIZE - 90 * SCALE, 22 * SCALE, WHITE)
draw_sparkle(draw, SIZE - 90 * SCALE, SIZE - 90 * SCALE, 22 * SCALE, GOLD_YELLOW)

# Downsample to 512 x 512
final_icon = img.resize((512, 512), Image.Resampling.LANCZOS)
final_icon.save("C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_crossed_clash.png")
print("Rendered crossed clash logo")
