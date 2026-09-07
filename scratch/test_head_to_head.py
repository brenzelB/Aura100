import math
from PIL import Image, ImageDraw

SCALE = 4
SIZE = 512 * SCALE

# Colors (ZERO VIOLET / PURPLE)
BG_COLOR = (20, 20, 24)         # Deep sleek obsidian charcoal
INK_BLACK = (10, 10, 12)        # Solid ink outline
GOLD_YELLOW = (255, 204, 0)     # #FFCC00 Champion Gold
GOLD_HI = (255, 238, 150)
CYBER_BLUE = (0, 145, 255)      # #0091FF Rival Blue
BLUE_HI = (160, 225, 255)
WHITE = (255, 255, 255)
ORANGE_SPARK = (255, 80, 30)

def rotate_pt(x, y, angle_rad):
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    return (x * cos_a - y * sin_a, x * sin_a + y * cos_a)

def get_full_lightning_bolt(head_x, head_y, length, width, angle_deg):
    """
    Creates a full, classic, unmistakable lightning bolt.
    head_x, head_y is the acute front tip of the bolt.
    angle_deg is the direction the bolt is pointing towards.
    """
    rad = math.radians(angle_deg)
    # Define bolt coordinates relative to its tip (0, 0) pointing in +X direction:
    # Tip is at (0, 0). Body extends backwards in -X direction.
    raw_pts = [
        (0.0 * length, 0.0 * width),            # 1. Acute front tip (impact point)
        (-0.50 * length, -0.42 * width),        # 2. Upper front barb
        (-0.36 * length, -0.12 * width),        # 3. Upper inner notch
        (-1.00 * length, -0.28 * width),        # 4. Tail top corner
        (-0.78 * length, 0.08 * width),         # 5. Tail inner crook
        (-0.42 * length, 0.12 * width),         # 6. Lower inner notch
        (-0.55 * length, 0.44 * width),         # 7. Lower front barb
    ]
    
    pts = []
    for rx, ry in raw_pts:
        rot_x, rot_y = rotate_pt(rx, ry, rad)
        pts.append((head_x + rot_x, head_y + rot_y))
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

# Central clash ambient glow
for r in range(420 * SCALE, 0, -25 * SCALE):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(28, 28, 36))

# Clash configuration:
# Left Bolt (Gold): comes from top-left, aimed downwards-right towards center (approx 32 deg)
# Tip stops just before center:
gap = 24 * SCALE
b1_tip_x = cx - gap
b1_tip_y = cy - gap * 0.6
b1_angle = 30
bolt_len = 360 * SCALE
bolt_w = 175 * SCALE

bolt1_pts = get_full_lightning_bolt(b1_tip_x, b1_tip_y, bolt_len, bolt_w, b1_angle)

# Right Bolt (Blue): comes from bottom-right, aimed upwards-left towards center (approx 210 deg = 30 + 180)
b2_tip_x = cx + gap
b2_tip_y = cy + gap * 0.6
b2_angle = 210

bolt2_pts = get_full_lightning_bolt(b2_tip_x, b2_tip_y, bolt_len, bolt_w, b2_angle)

# 1. Hard Offset Drop Shadows
sh_x = 22 * SCALE
sh_y = 22 * SCALE
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt2_pts], fill=INK_BLACK)
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt1_pts], fill=INK_BLACK)

# 2. Draw Bolt 2 (Cyber Blue)
draw.polygon(bolt2_pts, fill=CYBER_BLUE, outline=INK_BLACK, width=15 * SCALE)
# Inner highlight on blue bolt
draw.polygon(get_full_lightning_bolt(b2_tip_x - 10*SCALE, b2_tip_y - 6*SCALE, bolt_len*0.84, bolt_w*0.55, b2_angle), fill=BLUE_HI)

# 3. Draw Bolt 1 (Electric Gold)
draw.polygon(bolt1_pts, fill=GOLD_YELLOW, outline=INK_BLACK, width=15 * SCALE)
# Inner highlight on gold bolt
draw.polygon(get_full_lightning_bolt(b1_tip_x + 10*SCALE, b1_tip_y + 6*SCALE, bolt_len*0.84, bolt_w*0.55, b1_angle), fill=GOLD_HI)

# 4. Central Clash Explosion (The duel collision between their tips!)
draw_sparkle(draw, cx, cy, 105 * SCALE, WHITE, outline=INK_BLACK, out_w=8 * SCALE)
draw_sparkle(draw, cx, cy, 65 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx, cy, 30 * SCALE, WHITE)

# Electric arc sparks between tips
draw_sparkle(draw, cx - 70 * SCALE, cy + 50 * SCALE, 28 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx + 70 * SCALE, cy - 50 * SCALE, 28 * SCALE, CYBER_BLUE)
draw_sparkle(draw, cx + 55 * SCALE, cy + 70 * SCALE, 22 * SCALE, WHITE)
draw_sparkle(draw, cx - 55 * SCALE, cy - 70 * SCALE, 22 * SCALE, ORANGE_SPARK)

# Embers
draw.ellipse([cx - 130*SCALE, cy - 100*SCALE, cx - 116*SCALE, cy - 86*SCALE], fill=GOLD_YELLOW)
draw.ellipse([cx + 130*SCALE, cy + 100*SCALE, cx + 144*SCALE, cy + 114*SCALE], fill=CYBER_BLUE)
draw.ellipse([cx + 100*SCALE, cy - 120*SCALE, cx + 114*SCALE, cy - 106*SCALE], fill=WHITE)
draw.ellipse([cx - 100*SCALE, cy + 120*SCALE, cx - 86*SCALE, cy + 134*SCALE], fill=ORANGE_SPARK)

# Downsample to 512 x 512
final_icon = img.resize((512, 512), Image.Resampling.LANCZOS)
final_icon.save("C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_head_to_head.png")
print("Rendered head-to-head clash logo")
