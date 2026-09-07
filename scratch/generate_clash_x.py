import math
from PIL import Image, ImageDraw

SCALE = 4
SIZE = 512 * SCALE

# Colors (ZERO PURPLE / VIOLET)
BG_COLOR = (20, 20, 24)         # Deep sleek charcoal #141418
INK_BLACK = (8, 8, 10)          # Ultra-crisp black outline
GOLD_YELLOW = (255, 204, 0)     # #FFCC00 Primary Electric Gold
GOLD_HIGHLIGHT = (255, 242, 160)
CYBER_BLUE = (0, 145, 255)      # #0091FF Rival Electric Blue
BLUE_HIGHLIGHT = (160, 225, 255)
WHITE = (255, 255, 255)
ORANGE_SPARK = (255, 85, 30)

def rotate_pt(x, y, angle_rad):
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    return (x * cos_a - y * sin_a, x * sin_a + y * cos_a)

def get_iconic_bolt(cx, cy, length, width, angle_deg):
    angle_rad = math.radians(angle_deg)
    
    # Classic, readable, heavy-hitting lightning bolt shape
    raw_pts = [
        (0.0, -0.50 * length),             # Sharp top tip
        (-0.40 * width, -0.05 * length),   # Upper outer barb
        (-0.12 * width, -0.05 * length),   # Upper inner notch
        (0.04 * width, 0.50 * length),     # Sharp bottom tip
        (0.40 * width, 0.05 * length),     # Lower outer barb
        (0.12 * width, 0.05 * length),     # Lower inner notch
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

# Ambient energy clash field in background
for r in range(450 * SCALE, 0, -30 * SCALE):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(28, 28, 36))

bolt_len = 430 * SCALE
bolt_w = 210 * SCALE
angle = 42  # 42 degrees creates a dynamic X-clash

# Bolt 1: Electric Gold (striking from Top-Left to Bottom-Right)
bolt1_pts = get_iconic_bolt(cx, cy, bolt_len, bolt_w, angle)

# Bolt 2: Cyber Blue (striking from Top-Right to Bottom-Left)
bolt2_pts = get_iconic_bolt(cx, cy, bolt_len, bolt_w, -angle)

# 1. Hard Offset Shadows (6px offset down-right)
sh_x = 22 * SCALE
sh_y = 22 * SCALE
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt2_pts], fill=INK_BLACK)
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt1_pts], fill=INK_BLACK)

# 2. Draw Rival Bolt (Cyber Blue)
draw.polygon(bolt2_pts, fill=CYBER_BLUE, outline=INK_BLACK, width=16 * SCALE)
# Highlight facet
draw.polygon(get_iconic_bolt(cx - 4*SCALE, cy - 4*SCALE, bolt_len * 0.84, bolt_w * 0.54, -angle), fill=BLUE_HIGHLIGHT)

# 3. Draw Champion Bolt (Electric Gold)
draw.polygon(bolt1_pts, fill=GOLD_YELLOW, outline=INK_BLACK, width=16 * SCALE)
# Highlight facet
draw.polygon(get_iconic_bolt(cx - 4*SCALE, cy - 4*SCALE, bolt_len * 0.84, bolt_w * 0.54, angle), fill=GOLD_HIGHLIGHT)

# 4. Central Clash Star (The exact collision point)
draw_sparkle(draw, cx, cy, 110 * SCALE, WHITE, outline=INK_BLACK, out_w=8 * SCALE)
draw_sparkle(draw, cx, cy, 70 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx, cy, 32 * SCALE, WHITE)

# Flying clash sparks
draw_sparkle(draw, cx - 135 * SCALE, cy, 28 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx + 135 * SCALE, cy, 28 * SCALE, CYBER_BLUE)
draw_sparkle(draw, cx, cy - 135 * SCALE, 24 * SCALE, WHITE)
draw_sparkle(draw, cx, cy + 135 * SCALE, 24 * SCALE, ORANGE_SPARK)

# Small particle embers
draw.ellipse([cx - 160*SCALE, cy - 70*SCALE, cx - 145*SCALE, cy - 55*SCALE], fill=GOLD_YELLOW)
draw.ellipse([cx + 160*SCALE, cy + 70*SCALE, cx + 175*SCALE, cy + 85*SCALE], fill=CYBER_BLUE)
draw.ellipse([cx + 70*SCALE, cy - 160*SCALE, cx + 85*SCALE, cy - 145*SCALE], fill=WHITE)
draw.ellipse([cx - 70*SCALE, cy + 160*SCALE, cx - 55*SCALE, cy + 175*SCALE], fill=ORANGE_SPARK)

# Downsample to 512 x 512
final_icon = img.resize((512, 512), Image.Resampling.LANCZOS)

out1 = "d:/vibe projects/Aura 100/deploy/store/assets/icon_512.png"
out2 = "C:/Users/denis/Desktop/AuraQuest_Store_Bilder/icon_512.png"
out3 = "C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_clash_x.png"

final_icon.save(out1, "PNG", optimize=True)
final_icon.save(out2, "PNG", optimize=True)
final_icon.save(out3, "PNG", optimize=True)

print("Saved Clash X Logo!")
