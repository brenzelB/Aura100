import math
from PIL import Image, ImageDraw, ImageFont

# Canvas dimensions (2x supersampled for ultra-crisp anti-aliasing)
SCALE = 2
WIDTH = 1024 * SCALE   # 2048
HEIGHT = 500 * SCALE   # 1000

# Color Palette (Aura Quest Kinetic Neo-Brutalist)
BG_COLOR = (253, 239, 231)       # #FDEFE7 Warm Off-White
GRID_DOT = (235, 215, 203)       # Subtle grid dots
INK_BLACK = (25, 25, 25)         # #191919
WHITE = (255, 255, 255)          # #FFFFFF
YELLOW = (255, 199, 0)           # #FFC700 Primary Accent
PURPLE = (124, 58, 237)          # #7C3AED Kinetic Purple
LIGHT_PURPLE = (237, 233, 254)   # #EDE9FE
PINK = (255, 42, 133)            # #FF2A85 Neon Pink
LIGHT_PINK = (255, 228, 240)
GREEN = (0, 200, 83)             # #00C853 Success Green
LIGHT_GREEN = (220, 252, 231)
CYBER_BLUE = (0, 87, 255)        # #0057FF Secondary Blue
MUTED_TEXT = (79, 70, 50)        # #4F4632 Secondary text
LIGHT_YELLOW = (254, 243, 199)

img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
draw = ImageDraw.Draw(img)

# Load Fonts
def get_font(name, size):
    try:
        return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size * SCALE)
    except:
        return ImageFont.load_default()

font_hero = get_font("Roboto-Black.ttf", 44)
font_title = get_font("Roboto-Black.ttf", 22)
font_subtitle = get_font("Roboto-Bold.ttf", 15)
font_body = get_font("Roboto-Bold.ttf", 13)
font_body_regular = get_font("Roboto-Regular.ttf", 12)
font_badge = get_font("Roboto-Black.ttf", 11)
font_number = get_font("Roboto-Black.ttf", 15)
font_micro = get_font("Roboto-Bold.ttf", 10)

# 1. Background Grid Dots
dot_spacing = 32 * SCALE
dot_radius = 2 * SCALE
for x in range(dot_spacing // 2, WIDTH, dot_spacing):
    for y in range(dot_spacing // 2, HEIGHT, dot_spacing):
        draw.ellipse([x - dot_radius, y - dot_radius, x + dot_radius, y + dot_radius], fill=GRID_DOT)

# Helper: Draw Neo-Brutalist Box (hard shadow + crisp border)
def draw_neo_box(x, y, w, h, bg, radius=12*SCALE, border_w=3*SCALE, shadow_off=(6*SCALE, 6*SCALE), border_col=INK_BLACK, shadow_col=INK_BLACK):
    sx, sy = shadow_off
    # Shadow
    draw.rounded_rectangle([x + sx, y + sy, x + w + sx, y + h + sy], radius=radius, fill=shadow_col)
    # Box fill
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=bg)
    # Border
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, outline=border_col, width=border_w)

# Helper: Vector Lightning Bolt
def draw_lightning(cx, cy, w, h, fill=YELLOW, outline=INK_BLACK, border_w=2*SCALE):
    pts = [
        (cx + w*0.1, cy - h*0.5),
        (cx - w*0.4, cy + h*0.05),
        (cx - w*0.05, cy + h*0.05),
        (cx - w*0.25, cy + h*0.5),
        (cx + w*0.4, cy - h*0.05),
        (cx + w*0.05, cy - h*0.05),
    ]
    draw.polygon(pts, fill=fill, outline=outline)

# Helper: Vector Trophy with Handles
def draw_trophy(cx, cy, size, fill=WHITE, outline=INK_BLACK):
    s = size / 2.0
    # Handles
    draw.arc([cx - s*0.9, cy - s*0.55, cx - s*0.3, cy + s*0.05], start=90, end=270, fill=outline, width=2*SCALE)
    draw.arc([cx + s*0.3, cy - s*0.55, cx + s*0.9, cy + s*0.05], start=270, end=90, fill=outline, width=2*SCALE)
    # Cup
    cup_pts = [
        (cx - s*0.6, cy - s*0.55),
        (cx + s*0.6, cy - s*0.55),
        (cx + s*0.45, cy + s*0.05),
        (cx - s*0.45, cy + s*0.05),
    ]
    draw.polygon(cup_pts, fill=fill, outline=outline)
    # Stem
    draw.rectangle([cx - s*0.12, cy + s*0.05, cx + s*0.12, cy + s*0.35], fill=fill, outline=outline)
    # Base
    draw.rectangle([cx - s*0.5, cy + s*0.35, cx + s*0.5, cy + s*0.58], fill=fill, outline=outline)

# Helper: Vector Flame
def draw_flame(cx, cy, size, fill=YELLOW, outline=INK_BLACK):
    s = size / 2.0
    pts = [
        (cx, cy - s*0.7),
        (cx + s*0.45, cy - s*0.1),
        (cx + s*0.6, cy + s*0.5),
        (cx + s*0.2, cy + s*0.7),
        (cx, cy + s*0.4),
        (cx - s*0.2, cy + s*0.7),
        (cx - s*0.6, cy + s*0.5),
        (cx - s*0.45, cy - s*0.1),
    ]
    draw.polygon(pts, fill=fill, outline=outline)

# Helper: Vector Checkmark
def draw_check(cx, cy, size, color=WHITE, width=3*SCALE):
    s = size / 2.0
    pts = [
        (cx - s*0.6, cy),
        (cx - s*0.1, cy + s*0.6),
        (cx + s*0.7, cy - s*0.5)
    ]
    draw.line(pts, fill=color, width=width, joint="curve")

# Helper: 5-Point Star
def draw_star(cx, cy, r, fill=YELLOW, outline=INK_BLACK):
    pts = []
    for i in range(10):
        angle = i * (math.pi / 5) - math.pi / 2
        dist = r if i % 2 == 0 else r * 0.45
        pts.append((cx + dist * math.cos(angle), cy + dist * math.sin(angle)))
    draw.polygon(pts, fill=fill, outline=outline)

# Helper: 4-Point Brutalist Sparkle Star
def draw_sparkle(cx, cy, r, color):
    r_in = r * 0.22
    points = []
    for i in range(8):
        angle = i * (math.pi / 4)
        dist = r if i % 2 == 0 else r_in
        points.append((cx + dist * math.cos(angle), cy + dist * math.sin(angle)))
    draw.polygon(points, fill=color, outline=INK_BLACK)

# Helper: Draw Die Face
def draw_die(x, y, size, val, bg_col, pip_col):
    r = int(size * 0.22)
    bw = 2 * SCALE
    # Die shadow
    draw.rounded_rectangle([x + 3*SCALE, y + 3*SCALE, x + size + 3*SCALE, y + size + 3*SCALE], radius=r, fill=INK_BLACK)
    # Die face
    draw.rounded_rectangle([x, y, x + size, y + size], radius=r, fill=bg_col, outline=INK_BLACK, width=bw)
    
    # Pips
    pr = int(size * 0.085)
    c = size // 2
    l = int(size * 0.26)
    rt = size - l
    
    pip_coords = {
        1: [(c, c)],
        2: [(l, l), (rt, rt)],
        3: [(l, l), (c, c), (rt, rt)],
        4: [(l, l), (rt, l), (l, rt), (rt, rt)],
        5: [(l, l), (rt, l), (c, c), (l, rt), (rt, rt)],
        6: [(l, l), (rt, l), (l, c), (rt, c), (l, rt), (rt, rt)]
    }
    
    for px, py in pip_coords.get(val, []):
        draw.ellipse([x + px - pr, y + py - pr, x + px + pr, y + py + pr], fill=pip_col)


# ════════════════════════════════════════════════════════
# ── LEFT SECTION: HERO BRANDING ──
# ════════════════════════════════════════════════════════
left_x = 52 * SCALE
top_y = 56 * SCALE

# Tag pill: "GAMIFY YOUR HABITS • DUEL FRIENDS"
tag_w = 330 * SCALE
tag_h = 32 * SCALE
draw_neo_box(left_x, top_y, tag_w, tag_h, YELLOW, radius=tag_h//2, shadow_off=(4*SCALE, 4*SCALE))
draw_lightning(left_x + 18*SCALE, top_y + 16*SCALE, 12*SCALE, 16*SCALE, fill=INK_BLACK, outline=INK_BLACK)
draw.text((left_x + 32*SCALE, top_y + 7*SCALE), "GAMIFY YOUR HABITS  •  DUEL FRIENDS", font=font_badge, fill=INK_BLACK)

# App Title: AURA QUEST with hard offset brutalist shadow
title_y = top_y + 50 * SCALE
draw.text((left_x + 6*SCALE, title_y + 6*SCALE), "AURA QUEST", font=font_hero, fill=PURPLE)
draw.text((left_x, title_y), "AURA QUEST", font=font_hero, fill=INK_BLACK)

# Tagline & description
sub_y = title_y + 66 * SCALE
draw.text((left_x, sub_y), "Turn daily habits into high-stakes quests.", font=font_subtitle, fill=MUTED_TEXT)
draw.text((left_x, sub_y + 24*SCALE), "Stake your Aura, challenge rivals, level up together.", font=font_body_regular, fill=MUTED_TEXT)

# Feature Badges Row (3 distinct badges with custom icons)
badges_y = sub_y + 70 * SCALE

# Badge 1: 7-Day Streaks
b1_w = 126 * SCALE
b1_h = 30 * SCALE
draw_neo_box(left_x, badges_y, b1_w, b1_h, LIGHT_YELLOW, radius=6*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw_flame(left_x + 14*SCALE, badges_y + 15*SCALE, 14*SCALE, fill=YELLOW, outline=INK_BLACK)
draw.text((left_x + 26*SCALE, badges_y + 7*SCALE), "7D STREAKS", font=font_badge, fill=INK_BLACK)

# Badge 2: Dice Duels
b2_x = left_x + b1_w + 12 * SCALE
b2_w = 118 * SCALE
b2_h = 30 * SCALE
draw_neo_box(b2_x, badges_y, b2_w, b2_h, LIGHT_PURPLE, radius=6*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw_die(b2_x + 10*SCALE, badges_y + 7*SCALE, 15*SCALE, 5, PURPLE, WHITE)
draw.text((b2_x + 32*SCALE, badges_y + 7*SCALE), "DICE DUELS", font=font_badge, fill=INK_BLACK)

# Badge 3: Aura Stakes
b3_x = b2_x + b2_w + 12 * SCALE
b3_w = 120 * SCALE
b3_h = 30 * SCALE
draw_neo_box(b3_x, badges_y, b3_w, b3_h, LIGHT_GREEN, radius=6*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw_lightning(b3_x + 14*SCALE, badges_y + 15*SCALE, 12*SCALE, 15*SCALE, fill=GREEN, outline=INK_BLACK)
draw.text((b3_x + 26*SCALE, badges_y + 7*SCALE), "AURA STAKES", font=font_badge, fill=INK_BLACK)

# Social Proof & Theme tag
proof_y = badges_y + 48 * SCALE
proof_w = 260 * SCALE
proof_h = 32 * SCALE
draw_neo_box(left_x, proof_y, proof_w, proof_h, WHITE, radius=16*SCALE, shadow_off=(4*SCALE, 4*SCALE))
for i in range(5):
    draw_star(left_x + 18*SCALE + i * 16*SCALE, proof_y + 16*SCALE, 6*SCALE, fill=YELLOW)
draw.text((left_x + 106*SCALE, proof_y + 7*SCALE), "KINETIC NEO-BRUTALIST", font=font_badge, fill=PURPLE)


# ════════════════════════════════════════════════════════
# ── RIGHT SECTION: AUTHENTIC APP UI MOCKUP CARDS ──
# ════════════════════════════════════════════════════════

# CARD 1: ACTIVE QUEST CARD (Top Right)
c1_x = 520 * SCALE
c1_y = 38 * SCALE
c1_w = 460 * SCALE
c1_h = 164 * SCALE

draw_neo_box(c1_x, c1_y, c1_w, c1_h, WHITE, radius=16*SCALE, shadow_off=(7*SCALE, 7*SCALE))

# Trophy Box
t_box_size = 46 * SCALE
t_box_x = c1_x + 18 * SCALE
t_box_y = c1_y + 18 * SCALE
draw_neo_box(t_box_x, t_box_y, t_box_size, t_box_size, YELLOW, radius=10*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw_trophy(t_box_x + t_box_size//2, t_box_y + t_box_size//2, 26*SCALE, fill=WHITE, outline=INK_BLACK)

# Quest Title
draw.text((t_box_x + t_box_size + 16*SCALE, t_box_y + 2*SCALE), "Morning Workout", font=font_title, fill=INK_BLACK)

# Aura pill on top right
q_aura_w = 88 * SCALE
q_aura_h = 24 * SCALE
q_aura_x = c1_x + c1_w - q_aura_w - 18*SCALE
q_aura_y = t_box_y + 6*SCALE
draw.rounded_rectangle([q_aura_x, q_aura_y, q_aura_x + q_aura_w, q_aura_y + q_aura_h], radius=4*SCALE, fill=LIGHT_PURPLE, outline=PURPLE, width=SCALE)
draw_lightning(q_aura_x + 10*SCALE, q_aura_y + q_aura_h//2, 9*SCALE, 12*SCALE, fill=PURPLE, outline=PURPLE)
draw.text((q_aura_x + 22*SCALE, q_aura_y + 4*SCALE), "100 AURA", font=font_micro, fill=PURPLE)

# Badges inside Quest
q_badge_y = t_box_y + 46 * SCALE
q_badges = [
    ("2 Mates", (240, 245, 255)),
    ("7d left", LIGHT_YELLOW),
    ("+100", LIGHT_GREEN),
    ("-50", (255, 235, 235)),
]
qb_x = t_box_x + t_box_size + 16 * SCALE
for qb_text, qb_bg in q_badges:
    qbw = int(draw.textlength(qb_text, font=font_badge)) + 14 * SCALE
    qbh = 22 * SCALE
    draw.rounded_rectangle([qb_x, q_badge_y, qb_x + qbw, q_badge_y + qbh], radius=4*SCALE, fill=qb_bg, outline=INK_BLACK, width=SCALE)
    draw.text((qb_x + 7*SCALE, q_badge_y + 3*SCALE), qb_text, font=font_badge, fill=INK_BLACK)
    qb_x += qbw + 8 * SCALE

# Check-in Status & Buttons
c1_btn_y = c1_y + 108 * SCALE

# Done Checkmark Button
done_btn_w = 110 * SCALE
done_btn_h = 36 * SCALE
draw_neo_box(c1_x + c1_w - done_btn_w - 18*SCALE, c1_btn_y, done_btn_w, done_btn_h, GREEN, radius=8*SCALE, shadow_off=(4*SCALE, 4*SCALE))
draw_check(c1_x + c1_w - done_btn_w - 18*SCALE + 26*SCALE, c1_btn_y + 18*SCALE, 14*SCALE, color=WHITE, width=3*SCALE)
draw.text((c1_x + c1_w - done_btn_w - 18*SCALE + 44*SCALE, c1_btn_y + 8*SCALE), "DONE", font=font_body, fill=WHITE)

# Left links
draw.text((c1_x + 20*SCALE, c1_btn_y + 10*SCALE), "QUEST SHOP", font=font_badge, fill=PURPLE)
draw.text((c1_x + 120*SCALE, c1_btn_y + 10*SCALE), "0/1 STRIKES", font=font_badge, fill=MUTED_TEXT)


# CARD 2: REAL DICE DUEL CARD (Bottom Right)
c2_x = 520 * SCALE
c2_y = 236 * SCALE
c2_w = 460 * SCALE
c2_h = 226 * SCALE

draw_neo_box(c2_x, c2_y, c2_w, c2_h, WHITE, radius=16*SCALE, shadow_off=(7*SCALE, 7*SCALE))

# Duel Header
draw_die(c2_x + 20*SCALE, c2_y + 18*SCALE, 20*SCALE, 4, PURPLE, WHITE)
draw.text((c2_x + 48*SCALE, c2_y + 16*SCALE), "DICE DUEL", font=font_title, fill=INK_BLACK)

# Pot Pill: "50 AURA POT" safely nested inside card
pot_w = 120 * SCALE
pot_h = 26 * SCALE
pot_x = c2_x + c2_w - pot_w - 18*SCALE
pot_y = c2_y + 16 * SCALE
draw_neo_box(pot_x, pot_y, pot_w, pot_h, YELLOW, radius=pot_h//2, shadow_off=(2*SCALE, 2*SCALE), border_w=2*SCALE)
draw_lightning(pot_x + 12*SCALE, pot_y + pot_h//2, 8*SCALE, 12*SCALE, fill=INK_BLACK, outline=INK_BLACK)
draw.text((pot_x + 24*SCALE, pot_y + 4*SCALE), "50 AURA POT", font=font_micro, fill=INK_BLACK)

# Subtitle
draw.text((c2_x + 20*SCALE, c2_y + 46*SCALE), "Morning Workout  •  vs @bra_b", font=font_body_regular, fill=MUTED_TEXT)

# Opponent Row
p1_y = c2_y + 72 * SCALE
draw.ellipse([c2_x + 20*SCALE, p1_y, c2_x + 52*SCALE, p1_y + 32*SCALE], fill=WHITE, outline=INK_BLACK, width=2*SCALE)
draw.text((c2_x + 30*SCALE, p1_y + 6*SCALE), "B", font=font_body, fill=INK_BLACK)
draw.text((c2_x + 60*SCALE, p1_y + 6*SCALE), "@bra_b", font=font_body, fill=INK_BLACK)

# Opponent Dice: [ 6 ] [ 5 ]
draw_die(c2_x + 215*SCALE, p1_y - 2*SCALE, 36*SCALE, 6, (255, 235, 235), (220, 38, 38))
draw_die(c2_x + 260*SCALE, p1_y - 2*SCALE, 36*SCALE, 5, (255, 235, 235), (220, 38, 38))

# Opponent Score
draw_neo_box(c2_x + 316*SCALE, p1_y + 2*SCALE, 44*SCALE, 28*SCALE, WHITE, radius=6*SCALE, shadow_off=(2*SCALE, 2*SCALE))
draw.text((c2_x + 328*SCALE, p1_y + 6*SCALE), "11", font=font_body, fill=INK_BLACK)

# Center VS
vs_y = p1_y + 40 * SCALE
draw.text((c2_x + 248*SCALE, vs_y - 4*SCALE), "VS", font=font_badge, fill=MUTED_TEXT)

# User Row
p2_y = vs_y + 20 * SCALE
draw.ellipse([c2_x + 20*SCALE, p2_y, c2_x + 52*SCALE, p2_y + 32*SCALE], fill=YELLOW, outline=INK_BLACK, width=2*SCALE)
draw.text((c2_x + 30*SCALE, p2_y + 6*SCALE), "Y", font=font_body, fill=INK_BLACK)
draw.text((c2_x + 60*SCALE, p2_y + 6*SCALE), "YOU", font=font_body, fill=INK_BLACK)

# User Dice: [ 5 ] [ 5 ]
draw_die(c2_x + 215*SCALE, p2_y - 2*SCALE, 36*SCALE, 5, LIGHT_YELLOW, (200, 140, 0))
draw_die(c2_x + 260*SCALE, p2_y - 2*SCALE, 36*SCALE, 5, LIGHT_YELLOW, (200, 140, 0))

# User Score
draw_neo_box(c2_x + 316*SCALE, p2_y + 2*SCALE, 44*SCALE, 28*SCALE, WHITE, radius=6*SCALE, shadow_off=(2*SCALE, 2*SCALE))
draw.text((c2_x + 328*SCALE, p2_y + 6*SCALE), "10", font=font_body, fill=INK_BLACK)

# Duel Banner (Result)
duel_res_w = 420 * SCALE
duel_res_h = 32 * SCALE
draw_neo_box(c2_x + 20*SCALE, c2_y + 176*SCALE, duel_res_w, duel_res_h, LIGHT_GREEN, radius=6*SCALE, shadow_off=(3*SCALE, 3*SCALE), border_col=INK_BLACK)
draw_lightning(c2_x + 130*SCALE, c2_y + 192*SCALE, 10*SCALE, 14*SCALE, fill=GREEN, outline=GREEN)
draw.text((c2_x + 146*SCALE, c2_y + 182*SCALE), "WINNER TAKES ALL  •  +25 AURA", font=font_badge, fill=GREEN)


# ════════════════════════════════════════════════════════
# ── FLOATING ACCENT PILL & SPARKLES ──
# ════════════════════════════════════════════════════════

# Floating Balance Pill (Positioned cleanly between left and right)
bal_x = 405 * SCALE
bal_y = 196 * SCALE
bal_w = 170 * SCALE
bal_h = 40 * SCALE
draw_neo_box(bal_x, bal_y, bal_w, bal_h, PURPLE, radius=bal_h//2, shadow_off=(4*SCALE, 4*SCALE))
draw_lightning(bal_x + 22*SCALE, bal_y + 20*SCALE, 12*SCALE, 18*SCALE, fill=YELLOW, outline=WHITE)
draw.text((bal_x + 40*SCALE, bal_y + 10*SCALE), "1,250 AURA", font=font_body, fill=WHITE)

# Decorative Neo-Brutalist Sparkles
draw_sparkle(470*SCALE, 80*SCALE, 16*SCALE, YELLOW)
draw_sparkle(430*SCALE, 420*SCALE, 14*SCALE, PINK)
draw_sparkle(990*SCALE, 220*SCALE, 18*SCALE, PURPLE)
draw_sparkle(30*SCALE, 370*SCALE, 15*SCALE, GREEN)
draw_sparkle(995*SCALE, 450*SCALE, 12*SCALE, YELLOW)
draw_sparkle(28*SCALE, 160*SCALE, 10*SCALE, PURPLE)

# ── DOWNSAMPLE TO 1024 x 500 WITH LANCZOS FOR SUPREME SHARPNESS ──
final_img = img.resize((1024, 500), Image.Resampling.LANCZOS)

out_path1 = "d:/vibe projects/Aura 100/deploy/store/assets/feature_graphic_1024x500.png"
out_path2 = "C:/Users/denis/Desktop/AuraQuest_Store_Bilder/feature_graphic_1024x500.png"
out_brain = "C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/feature_graphic_neo_brutalist_1024x500.png"

final_img.save(out_path1, "PNG", optimize=True)
final_img.save(out_path2, "PNG", optimize=True)
final_img.save(out_brain, "PNG", optimize=True)

print("SUCCESS: Vector Neo-Brutalist Feature Graphic regenerated with perfect alignment!")
