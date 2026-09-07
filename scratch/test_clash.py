import math
from PIL import Image, ImageDraw

SCALE = 4
SIZE = 512 * SCALE

# Background: Premium dark sleek charcoal (Dark Mode matches both Android and modern app aesthetics)
BG_COLOR = (24, 24, 28)         # #18181C
INK_BLACK = (12, 12, 14)        # #0C0C0E
YELLOW_BOLT = (255, 200, 0)     # #FFC800 Electric Gold
BLUE_BOLT = (0, 140, 255)       # #008CFF Cyan/Electric Blue (or Coral)
WHITE = (255, 255, 255)
SPARK_GOLD = (255, 220, 80)
SPARK_RED = (255, 70, 50)

def rotate_pt(x, y, angle_rad):
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    return (x * cos_a - y * sin_a, x * sin_a + y * cos_a)

def get_classic_bolt(cx, cy, length, width, angle_deg):
    angle_rad = math.radians(angle_deg)
    
    # Sharp, iconic, aggressive 6-point lightning bolt
    # Base shape pointing upwards (0, -0.5*L) to (0, 0.5*L)
    raw_pts = [
        (0.0, -0.50 * length),              # Sharp head
        (-0.38 * width, -0.02 * length),    # Left corner
        (-0.06 * width, -0.02 * length),    # Left inner crook
        (0.02 * width, 0.50 * length),      # Sharp tail
        (0.38 * width, 0.02 * length),      # Right corner
        (0.06 * width, 0.02 * length),      # Right inner crook
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

# Center of canvas
cx = SIZE // 2
cy = SIZE // 2

# Two bolts striking towards center:
# Bolt 1: Coming from top-left, pointing towards center-bottom-right (Angle ~ 135 deg)
# Bolt 2: Coming from bottom-right, pointing towards center-top-left (Angle ~ -45 deg)
bolt_len = 340 * SCALE
bolt_w = 190 * SCALE

# Bolt 1 (Yellow) head is near center (-25, -25), tail is at top-left
# If angle is 135: head is at (0, -0.5L) rotated, so let's adjust center so tips almost touch near (cx, cy)
b1_cx = cx - 110 * SCALE
b1_cy = cy - 110 * SCALE
bolt1_pts = get_classic_bolt(b1_cx, b1_cy, bolt_len, bolt_w, -45)

# Bolt 2 (Blue) head is near center (+25, +25), tail is at bottom-right
b2_cx = cx + 110 * SCALE
b2_cy = cy + 110 * SCALE
bolt2_pts = get_classic_bolt(b2_cx, b2_cy, bolt_len, bolt_w, 135)

# 1. Hard Drop Shadows
sh_x = 18 * SCALE
sh_y = 18 * SCALE
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt1_pts], fill=INK_BLACK)
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt2_pts], fill=INK_BLACK)

# 2. Draw Bolt 2 (Electric Blue)
draw.polygon(bolt2_pts, fill=BLUE_BOLT, outline=INK_BLACK, width=12 * SCALE)

# 3. Draw Bolt 1 (Electric Gold/Yellow)
draw.polygon(bolt1_pts, fill=YELLOW_BOLT, outline=INK_BLACK, width=12 * SCALE)

# Inner highlights
# On Yellow bolt
draw.polygon(get_classic_bolt(b1_cx - 4*SCALE, b1_cy - 4*SCALE, bolt_len*0.82, bolt_w*0.5, -45), fill=(255, 235, 120))
# On Blue bolt
draw.polygon(get_classic_bolt(b2_cx + 4*SCALE, b2_cy + 4*SCALE, bolt_len*0.82, bolt_w*0.5, 135), fill=(140, 210, 255))

# 4. Central Clash Spark (Impact Explosion)
draw_sparkle(draw, cx, cy, 70 * SCALE, WHITE, outline=INK_BLACK, out_w=5 * SCALE)
draw_sparkle(draw, cx, cy, 45 * SCALE, SPARK_GOLD)
draw_sparkle(draw, cx, cy, 22 * SCALE, WHITE)

# Flying energy sparks
draw_sparkle(draw, cx - 130 * SCALE, cy + 30 * SCALE, 22 * SCALE, YELLOW_BOLT)
draw_sparkle(draw, cx + 130 * SCALE, cy - 30 * SCALE, 22 * SCALE, BLUE_BOLT)
draw_sparkle(draw, cx + 40 * SCALE, cy - 130 * SCALE, 18 * SCALE, WHITE)
draw_sparkle(draw, cx - 40 * SCALE, cy + 130 * SCALE, 18 * SCALE, SPARK_RED)

# Downsample to 512 x 512
final_icon = img.resize((512, 512), Image.Resampling.LANCZOS)
final_icon.save("C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_test_clash.png")
print("Rendered test clash logo")
