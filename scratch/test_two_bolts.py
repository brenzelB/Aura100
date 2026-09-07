import math
from PIL import Image, ImageDraw

SCALE = 4
SIZE = 512 * SCALE

# Background: Premium dark charcoal/obsidian
BG_COLOR = (22, 22, 26)         # #16161A
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

def get_classic_lightning(head_x, head_y, length, width, angle_deg):
    """
    Classic, unmistakable ⚡ zigzag lightning bolt.
    head_x, head_y is the acute tip.
    angle_deg is the direction the bolt is pointing towards.
    """
    rad = math.radians(angle_deg)
    
    # Coordinates where (0, 0) is the sharp tip pointing along +X
    # Body extends backwards along -X:
    # 1. Tip: (0, 0)
    # 2. Upper zig: (-0.45*L, -0.28*W)
    # 3. Inner crook: (-0.35*L, -0.05*W)
    # 4. Tail top: (-0.95*L, -0.40*W)
    # 5. Tail back: (-1.00*L, 0.05*W)
    # 6. Lower inner crook: (-0.55*L, 0.10*W)
    # 7. Lower outer zig: (-0.65*L, 0.35*W)
    raw_pts = [
        (0.00 * length, 0.00 * width),           # Tip
        (-0.46 * length, -0.26 * width),         # Front top barb
        (-0.36 * length, -0.04 * width),         # Inner top notch
        (-0.96 * length, -0.38 * width),         # Tail top barb
        (-0.82 * length, 0.08 * width),          # Tail back
        (-0.50 * length, 0.12 * width),          # Inner bottom notch
        (-0.58 * length, 0.36 * width),          # Front bottom barb
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

# Ambient clash glow
for r in range(420 * SCALE, 0, -25 * SCALE):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(28, 28, 36))

# Two distinct classic ⚡ bolts meeting in center:
# Bolt 1: Gold, striking from top-left to center (angle = 35 deg)
# Bolt 2: Blue, striking from bottom-right to center (angle = 215 deg)
bolt_len = 380 * SCALE
bolt_w = 210 * SCALE

b1_tip_x = cx - 25 * SCALE
b1_tip_y = cy - 18 * SCALE
bolt1_pts = get_classic_lightning(b1_tip_x, b1_tip_y, bolt_len, bolt_w, 35)

b2_tip_x = cx + 25 * SCALE
b2_tip_y = cy + 18 * SCALE
bolt2_pts = get_classic_lightning(b2_tip_x, b2_tip_y, bolt_len, bolt_w, 215)

# 1. Hard Offset Drop Shadows
sh_x = 22 * SCALE
sh_y = 22 * SCALE
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt2_pts], fill=INK_BLACK)
draw.polygon([(x + sh_x, y + sh_y) for (x, y) in bolt1_pts], fill=INK_BLACK)

# 2. Draw Bolt 2 (Cyber Blue)
draw.polygon(bolt2_pts, fill=CYBER_BLUE, outline=INK_BLACK, width=16 * SCALE)
# Highlight facet
draw.polygon(get_classic_lightning(b2_tip_x - 8*SCALE, b2_tip_y - 6*SCALE, bolt_len*0.82, bolt_w*0.58, 215), fill=BLUE_HI)

# 3. Draw Bolt 1 (Electric Gold)
draw.polygon(bolt1_pts, fill=GOLD_YELLOW, outline=INK_BLACK, width=16 * SCALE)
# Highlight facet
draw.polygon(get_classic_lightning(b1_tip_x + 8*SCALE, b1_tip_y + 6*SCALE, bolt_len*0.82, bolt_w*0.58, 35), fill=GOLD_HI)

# 4. Central Clash Explosion (The duel collision between their tips!)
draw_sparkle(draw, cx, cy, 110 * SCALE, WHITE, outline=INK_BLACK, out_w=8 * SCALE)
draw_sparkle(draw, cx, cy, 70 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx, cy, 32 * SCALE, WHITE)

# Electric arc sparks
draw_sparkle(draw, cx - 80 * SCALE, cy + 60 * SCALE, 26 * SCALE, GOLD_YELLOW)
draw_sparkle(draw, cx + 80 * SCALE, cy - 60 * SCALE, 26 * SCALE, CYBER_BLUE)
draw_sparkle(draw, cx + 60 * SCALE, cy + 80 * SCALE, 20 * SCALE, WHITE)
draw_sparkle(draw, cx - 60 * SCALE, cy - 80 * SCALE, 20 * SCALE, ORANGE_SPARK)

# Embers
draw.ellipse([cx - 140*SCALE, cy - 110*SCALE, cx - 124*SCALE, cy - 94*SCALE], fill=GOLD_YELLOW)
draw.ellipse([cx + 140*SCALE, cy + 110*SCALE, cx + 156*SCALE, cy + 126*SCALE], fill=CYBER_BLUE)
draw.ellipse([cx + 110*SCALE, cy - 130*SCALE, cx + 124*SCALE, cy - 116*SCALE], fill=WHITE)
draw.ellipse([cx - 110*SCALE, cy + 130*SCALE, cx - 94*SCALE, cy + 146*SCALE], fill=ORANGE_SPARK)

# Downsample to 512 x 512
final_icon = img.resize((512, 512), Image.Resampling.LANCZOS)
final_icon.save("C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/icon_512_two_bolts.png")
print("Rendered two bolts meeting logo")
