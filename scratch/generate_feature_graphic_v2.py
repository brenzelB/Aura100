import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Canvas dimensions (2x supersampled for ultra-crisp anti-aliasing)
SCALE = 2
WIDTH = 1024 * SCALE   # 2048
HEIGHT = 500 * SCALE   # 1000

# Color Palette: ZERO PURPLE / VIOLET
BG_COLOR = (253, 251, 247)       # #FDFBF7 Warm Clean Off-White
GRID_DOT = (230, 226, 218)       # Subtle grid dots
INK_BLACK = (20, 21, 25)         # #141519 Crisp Deep Black
WHITE = (255, 255, 255)          # #FFFFFF
YELLOW = (255, 199, 0)           # #FFC700 Electric Gold / Yellow
LIGHT_YELLOW = (254, 243, 199)   # #FEF3C7
CYBER_BLUE = (0, 110, 255)       # #006EFF Cyber Blue
LIGHT_BLUE = (224, 242, 254)     # #E0F2FE
GREEN = (0, 200, 83)             # #00C853 Success Mint Green
LIGHT_GREEN = (220, 252, 231)    # #DCFCE7
MUTED_TEXT = (90, 85, 80)        # #5A5550 Warm Charcoal Muted
BORDER_COLOR = (20, 21, 25)

img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
draw = ImageDraw.Draw(img)

# Load Fonts
def get_font(name, size):
    try:
        return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size * SCALE)
    except:
        return ImageFont.load_default()

font_hero = get_font("Roboto-Black.ttf", 46)
font_title = get_font("Roboto-Black.ttf", 20)
font_subtitle = get_font("Roboto-Bold.ttf", 16)
font_body = get_font("Roboto-Bold.ttf", 13)
font_body_regular = get_font("Roboto-Regular.ttf", 12)
font_badge = get_font("Roboto-Black.ttf", 11)
font_number = get_font("Roboto-Black.ttf", 14)
font_micro = get_font("Roboto-Bold.ttf", 10)

# 1. Background Grid Dots
dot_spacing = 32 * SCALE
dot_radius = 2 * SCALE
for x in range(dot_spacing // 2, WIDTH, dot_spacing):
    for y in range(dot_spacing // 2, HEIGHT, dot_spacing):
        draw.ellipse([x - dot_radius, y - dot_radius, x + dot_radius, y + dot_radius], fill=GRID_DOT)

# Helper: Box with hard shadow and crisp border
def draw_box(x, y, w, h, bg, radius=12*SCALE, border_w=3*SCALE, shadow_off=(6*SCALE, 6*SCALE), border_col=INK_BLACK, shadow_col=INK_BLACK):
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

# Helper: Vector Trophy
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

# Helper: 4-Point Sparkle
def draw_sparkle(cx, cy, r, color):
    r_in = r * 0.22
    points = []
    for i in range(8):
        angle = i * (math.pi / 4)
        dist = r if i % 2 == 0 else r_in
        points.append((cx + dist * math.cos(angle), cy + dist * math.sin(angle)))
    draw.polygon(points, fill=color, outline=INK_BLACK)

# Helper: Vector Users (2 silhouettes)
def draw_users_icon(cx, cy, size, fill=CYBER_BLUE):
    s = size / 2.0
    # Left user (behind)
    draw.ellipse([cx - s*0.7, cy - s*0.65, cx - s*0.1, cy - s*0.05], fill=MUTED_TEXT)
    draw.arc([cx - s*0.9, cy + s*0.05, cx + s*0.1, cy + s*0.9], start=180, end=0, fill=MUTED_TEXT, width=int(2.5*SCALE))
    # Right user (front)
    draw.ellipse([cx - s*0.1, cy - s*0.5, cx + s*0.6, cy + s*0.2], fill=fill)
    draw.arc([cx - s*0.4, cy + s*0.25, cx + s*0.9, cy + s*1.1], start=180, end=0, fill=fill, width=int(2.5*SCALE))

# Helper: Vector Swords / Clash
def draw_clash_icon(cx, cy, size, col1=YELLOW, col2=CYBER_BLUE):
    s = size / 2.0
    # Blade 1
    draw.line([(cx - s*0.7, cy + s*0.7), (cx + s*0.7, cy - s*0.7)], fill=col1, width=int(3*SCALE))
    draw.line([(cx - s*0.4, cy + s*0.1), (cx - s*0.1, cy + s*0.4)], fill=INK_BLACK, width=int(2*SCALE))
    # Blade 2
    draw.line([(cx + s*0.7, cy + s*0.7), (cx - s*0.7, cy - s*0.7)], fill=col2, width=int(3*SCALE))
    draw.line([(cx + s*0.4, cy + s*0.1), (cx + s*0.1, cy + s*0.4)], fill=INK_BLACK, width=int(2*SCALE))


# ════════════════════════════════════════════════════════
# ── LEFT SECTION: VALUE PROPOSITION (NO JARGON) ──
# ════════════════════════════════════════════════════════
left_x = 52 * SCALE
top_y = 52 * SCALE

# Category Pill: "HABITS • QUESTS • FREUNDE"
tag_w = 320 * SCALE
tag_h = 32 * SCALE
draw_box(left_x, top_y, tag_w, tag_h, YELLOW, radius=tag_h//2, shadow_off=(4*SCALE, 4*SCALE))
draw_lightning(left_x + 18*SCALE, top_y + 16*SCALE, 12*SCALE, 16*SCALE, fill=INK_BLACK, outline=INK_BLACK)
draw.text((left_x + 32*SCALE, top_y + 7*SCALE), "HABITS  •  QUESTS  •  FREUNDE", font=font_badge, fill=INK_BLACK)

# App Title: AURA QUEST (Bold, Electric Gold hard shadow, NO PURPLE!)
title_y = top_y + 48 * SCALE
draw.text((left_x + 5*SCALE, title_y + 5*SCALE), "AURA QUEST", font=font_hero, fill=YELLOW)
draw.text((left_x, title_y), "AURA QUEST", font=font_hero, fill=INK_BLACK)

# Core Benefit Taglines
sub_y = title_y + 64 * SCALE
draw.text((left_x, sub_y), "Ziele als Quests mit Freunden durchziehen.", font=font_subtitle, fill=INK_BLACK)
draw.text((left_x, sub_y + 24*SCALE), "Tägliche Habits tracken, Streaks aufbauen und", font=font_body_regular, fill=MUTED_TEXT)
draw.text((left_x, sub_y + 42*SCALE), "dich mit Freunden in spannenden Challenges duellieren.", font=font_body_regular, fill=MUTED_TEXT)

# 3 Feature Pills (Clean, practical, benefit-focused)
badges_y = sub_y + 76 * SCALE

# Feature 1: Team-Quests
f1_w = 405 * SCALE
f1_h = 36 * SCALE
draw_box(left_x, badges_y, f1_w, f1_h, WHITE, radius=8*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw.ellipse([left_x + 8*SCALE, badges_y + 6*SCALE, left_x + 32*SCALE, badges_y + 30*SCALE], fill=LIGHT_BLUE, outline=CYBER_BLUE, width=SCALE)
draw_users_icon(left_x + 20*SCALE, badges_y + 18*SCALE, 14*SCALE, fill=CYBER_BLUE)
draw.text((left_x + 40*SCALE, badges_y + 9*SCALE), "Gemeinsame Quests", font=font_body, fill=INK_BLACK)
draw.text((left_x + 185*SCALE, badges_y + 10*SCALE), "• Gewohnheiten im Team meistern", font=font_body_regular, fill=MUTED_TEXT)

# Feature 2: Freunde challengen
f2_y = badges_y + 46 * SCALE
draw_box(left_x, f2_y, f1_w, f1_h, WHITE, radius=8*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw.ellipse([left_x + 8*SCALE, f2_y + 6*SCALE, left_x + 32*SCALE, f2_y + 30*SCALE], fill=LIGHT_YELLOW, outline=YELLOW, width=SCALE)
draw_clash_icon(left_x + 20*SCALE, f2_y + 18*SCALE, 14*SCALE, col1=YELLOW, col2=CYBER_BLUE)
draw.text((left_x + 40*SCALE, f2_y + 9*SCALE), "Freunde challengen", font=font_body, fill=INK_BLACK)
draw.text((left_x + 185*SCALE, f2_y + 10*SCALE), "• Wer hält die Streak länger?", font=font_body_regular, fill=MUTED_TEXT)

# Feature 3: Tägliche Streaks
f3_y = f2_y + 46 * SCALE
draw_box(left_x, f3_y, f1_w, f1_h, WHITE, radius=8*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw.ellipse([left_x + 8*SCALE, f3_y + 6*SCALE, left_x + 32*SCALE, f3_y + 30*SCALE], fill=LIGHT_GREEN, outline=GREEN, width=SCALE)
draw_flame(left_x + 20*SCALE, f3_y + 18*SCALE, 14*SCALE, fill=YELLOW, outline=INK_BLACK)
draw.text((left_x + 40*SCALE, f3_y + 9*SCALE), "Tägliche Streaks", font=font_body, fill=INK_BLACK)
draw.text((left_x + 185*SCALE, f3_y + 10*SCALE), "• Aura Belohnungen verdienen", font=font_body_regular, fill=MUTED_TEXT)

# Bottom Accountability Badge
proof_y = f3_y + 54 * SCALE
proof_w = 340 * SCALE
proof_h = 32 * SCALE
draw_box(left_x, proof_y, proof_w, proof_h, LIGHT_YELLOW, radius=proof_h//2, shadow_off=(3*SCALE, 3*SCALE))
draw_lightning(left_x + 16*SCALE, proof_y + 16*SCALE, 10*SCALE, 14*SCALE, fill=YELLOW, outline=INK_BLACK)
draw.text((left_x + 30*SCALE, proof_y + 8*SCALE), "ECHTE ACCOUNTABILITY DURCH FREUNDE", font=font_badge, fill=INK_BLACK)


# ════════════════════════════════════════════════════════
# ── RIGHT SECTION: AUTHENTIC APP FEATURE CARDS ──
# ════════════════════════════════════════════════════════

# CARD 1: GEMEINSAME QUEST CARD (Morning Workout)
c1_x = 515 * SCALE
c1_y = 38 * SCALE
c1_w = 465 * SCALE
c1_h = 180 * SCALE

draw_box(c1_x, c1_y, c1_w, c1_h, WHITE, radius=16*SCALE, shadow_off=(7*SCALE, 7*SCALE))

# Icon Box (Trophy/Target with Gold)
t_box_size = 46 * SCALE
t_box_x = c1_x + 18 * SCALE
t_box_y = c1_y + 18 * SCALE
draw_box(t_box_x, t_box_y, t_box_size, t_box_size, YELLOW, radius=10*SCALE, shadow_off=(3*SCALE, 3*SCALE))
draw_trophy(t_box_x + t_box_size//2, t_box_y + t_box_size//2, 26*SCALE, fill=WHITE, outline=INK_BLACK)

# Quest Title & Category
draw.text((t_box_x + t_box_size + 14*SCALE, t_box_y + 2*SCALE), "Morning Workout", font=font_title, fill=INK_BLACK)
draw.text((t_box_x + t_box_size + 14*SCALE, t_box_y + 26*SCALE), "Tägliche Team-Quest  •  Fitness & Gym", font=font_body_regular, fill=MUTED_TEXT)

# Aura Reward Pill
q_aura_w = 96 * SCALE
q_aura_h = 26 * SCALE
q_aura_x = c1_x + c1_w - q_aura_w - 18*SCALE
q_aura_y = t_box_y + 4*SCALE
draw_box(q_aura_x, q_aura_y, q_aura_w, q_aura_h, LIGHT_YELLOW, radius=6*SCALE, shadow_off=(2*SCALE, 2*SCALE), border_w=2*SCALE)
draw_lightning(q_aura_x + 12*SCALE, q_aura_y + q_aura_h//2, 9*SCALE, 13*SCALE, fill=YELLOW, outline=INK_BLACK)
draw.text((q_aura_x + 24*SCALE, q_aura_y + 5*SCALE), "+100 AURA", font=font_badge, fill=INK_BLACK)

# Team Member Check-In Row
team_y = t_box_y + 54 * SCALE
team_bg_w = c1_w - 36 * SCALE
team_bg_h = 36 * SCALE
draw.rounded_rectangle([c1_x + 18*SCALE, team_y, c1_x + 18*SCALE + team_bg_w, team_y + team_bg_h], radius=6*SCALE, fill=LIGHT_GREEN, outline=GREEN, width=SCALE)

# 3 Checked Avatars
av_size = 24 * SCALE
av_y = team_y + 6 * SCALE
# Av 1 (You)
draw.ellipse([c1_x + 28*SCALE, av_y, c1_x + 28*SCALE + av_size, av_y + av_size], fill=YELLOW, outline=INK_BLACK, width=SCALE)
draw.text((c1_x + 33*SCALE, av_y + 4*SCALE), "DU", font=font_micro, fill=INK_BLACK)
# Av 2 (Alex)
draw.ellipse([c1_x + 56*SCALE, av_y, c1_x + 56*SCALE + av_size, av_y + av_size], fill=CYBER_BLUE, outline=INK_BLACK, width=SCALE)
draw.text((c1_x + 60*SCALE, av_y + 4*SCALE), "AL", font=font_micro, fill=WHITE)
# Av 3 (Bra_b)
draw.ellipse([c1_x + 84*SCALE, av_y, c1_x + 84*SCALE + av_size, av_y + av_size], fill=WHITE, outline=INK_BLACK, width=SCALE)
draw.text((c1_x + 88*SCALE, av_y + 4*SCALE), "BB", font=font_micro, fill=INK_BLACK)

draw.text((c1_x + 118*SCALE, team_y + 9*SCALE), "Team-Check-in: 3 von 3 heute erledigt!", font=font_body, fill=INK_BLACK)
draw_check(c1_x + team_bg_w - 6*SCALE, team_y + team_bg_h//2, 12*SCALE, color=GREEN, width=int(2.5*SCALE))

# Bottom Row: Badges and Action Button
b_row_y = c1_y + 120 * SCALE
draw_box(c1_x + 18*SCALE, b_row_y + 4*SCALE, 108*SCALE, 28*SCALE, LIGHT_YELLOW, radius=6*SCALE, shadow_off=(2*SCALE, 2*SCALE), border_w=2*SCALE)
draw_flame(c1_x + 30*SCALE, b_row_y + 18*SCALE, 14*SCALE, fill=YELLOW, outline=INK_BLACK)
draw.text((c1_x + 42*SCALE, b_row_y + 10*SCALE), "7D STREAK", font=font_badge, fill=INK_BLACK)

# Check-in Button
done_btn_w = 175 * SCALE
done_btn_h = 38 * SCALE
done_btn_x = c1_x + c1_w - done_btn_w - 18*SCALE
draw_box(done_btn_x, b_row_y, done_btn_w, done_btn_h, GREEN, radius=8*SCALE, shadow_off=(4*SCALE, 4*SCALE))
draw_check(done_btn_x + 24*SCALE, b_row_y + done_btn_h//2, 16*SCALE, color=WHITE, width=3*SCALE)
draw.text((done_btn_x + 42*SCALE, b_row_y + 9*SCALE), "CHECK-IN ERLEDIGT", font=font_body, fill=WHITE)


# CARD 2: CHALLENGE & DUELL CARD (Streak-Duell)
c2_x = 515 * SCALE
c2_y = 244 * SCALE
c2_w = 465 * SCALE
c2_h = 216 * SCALE

draw_box(c2_x, c2_y, c2_w, c2_h, WHITE, radius=16*SCALE, shadow_off=(7*SCALE, 7*SCALE))

# Load miniature clashing lightning logo if available, or draw clash emblem
logo_path = "d:/vibe projects/Aura 100/deploy/store/assets/icon_512.png"
logo_size = 46 * SCALE
logo_x = c2_x + 18 * SCALE
logo_y = c2_y + 16 * SCALE

if os.path.exists(logo_path):
    try:
        mini_logo = Image.open(logo_path).convert("RGBA")
        mini_logo = mini_logo.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
        # Rounded mask for mini logo
        l_mask = Image.new("L", (logo_size, logo_size), 0)
        l_mdraw = ImageDraw.Draw(l_mask)
        l_mdraw.rounded_rectangle([0, 0, logo_size, logo_size], radius=10*SCALE, fill=255)
        
        # Draw shadow
        draw.rounded_rectangle([logo_x + 3*SCALE, logo_y + 3*SCALE, logo_x + logo_size + 3*SCALE, logo_y + logo_size + 3*SCALE], radius=10*SCALE, fill=INK_BLACK)
        # Paste with mask
        img.paste(mini_logo, (logo_x, logo_y), l_mask)
        draw.rounded_rectangle([logo_x, logo_y, logo_x + logo_size, logo_y + logo_size], radius=10*SCALE, outline=INK_BLACK, width=2*SCALE)
    except Exception as e:
        draw_box(logo_x, logo_y, logo_size, logo_size, INK_BLACK, radius=10*SCALE, shadow_off=(3*SCALE, 3*SCALE))
        draw_clash_icon(logo_x + logo_size//2, logo_y + logo_size//2, 24*SCALE)
else:
    draw_box(logo_x, logo_y, logo_size, logo_size, INK_BLACK, radius=10*SCALE, shadow_off=(3*SCALE, 3*SCALE))
    draw_clash_icon(logo_x + logo_size//2, logo_y + logo_size//2, 24*SCALE)

# Title & Subtitle
draw.text((logo_x + logo_size + 14*SCALE, logo_y + 2*SCALE), "Streak Challenge", font=font_title, fill=INK_BLACK)
draw.text((logo_x + logo_size + 14*SCALE, logo_y + 26*SCALE), "1v1 Duell  •  Wer hält länger durch?", font=font_body_regular, fill=MUTED_TEXT)

# Stakes Pill
pool_w = 112 * SCALE
pool_h = 26 * SCALE
pool_x = c2_x + c2_w - pool_w - 18*SCALE
pool_y = logo_y + 4 * SCALE
draw_box(pool_x, pool_y, pool_w, pool_h, YELLOW, radius=6*SCALE, shadow_off=(2*SCALE, 2*SCALE), border_w=2*SCALE)
draw_lightning(pool_x + 12*SCALE, pool_y + pool_h//2, 8*SCALE, 12*SCALE, fill=INK_BLACK, outline=INK_BLACK)
draw.text((pool_x + 24*SCALE, pool_y + 5*SCALE), "100 AURA POOL", font=font_badge, fill=INK_BLACK)

# Matchup Area: Player 1 (You) vs Player 2 (@bra_b)
m_y = logo_y + 56 * SCALE

# Player 1 Row (Du)
draw.text((c2_x + 20*SCALE, m_y), "DU (Streak: 7 Tage)", font=font_body, fill=INK_BLACK)
draw.text((c2_x + c2_w - 100*SCALE, m_y), "100% aktiv", font=font_body, fill=GREEN)
# Progress Bar 1 (You)
bar_w = c2_w - 40 * SCALE
bar_h = 10 * SCALE
bar1_y = m_y + 20 * SCALE
draw.rounded_rectangle([c2_x + 20*SCALE, bar1_y, c2_x + 20*SCALE + bar_w, bar1_y + bar_h], radius=5*SCALE, fill=(235, 235, 235), outline=INK_BLACK, width=SCALE)
draw.rounded_rectangle([c2_x + 20*SCALE, bar1_y, c2_x + 20*SCALE + bar_w, bar1_y + bar_h], radius=5*SCALE, fill=GREEN)

# Player 2 Row (@bra_b)
p2_y = bar1_y + 18 * SCALE
draw.text((c2_x + 20*SCALE, p2_y), "@bra_b (Streak: 6 Tage)", font=font_body, fill=MUTED_TEXT)
draw.text((c2_x + c2_w - 100*SCALE, p2_y), "85% aktiv", font=font_body, fill=CYBER_BLUE)
# Progress Bar 2 (@bra_b)
bar2_y = p2_y + 20 * SCALE
draw.rounded_rectangle([c2_x + 20*SCALE, bar2_y, c2_x + 20*SCALE + bar_w, bar2_y + bar_h], radius=5*SCALE, fill=(235, 235, 235), outline=INK_BLACK, width=SCALE)
draw.rounded_rectangle([c2_x + 20*SCALE, bar2_y, c2_x + 20*SCALE + int(bar_w * 0.85), bar2_y + bar_h], radius=5*SCALE, fill=CYBER_BLUE)

# Duell Status Banner at bottom of Card 2
stat_y = bar2_y + 22 * SCALE
stat_w = c2_w - 36 * SCALE
stat_h = 32 * SCALE
draw_box(c2_x + 18*SCALE, stat_y, stat_w, stat_h, LIGHT_BLUE, radius=6*SCALE, shadow_off=(3*SCALE, 3*SCALE), border_col=INK_BLACK)
draw_lightning(c2_x + 32*SCALE, stat_y + stat_h//2, 8*SCALE, 13*SCALE, fill=CYBER_BLUE, outline=CYBER_BLUE)
draw.text((c2_x + 44*SCALE, stat_y + 7*SCALE), "DUELL AKTIV • Du führst mit +1 Tag Vorsprung!", font=font_body, fill=CYBER_BLUE)


# ════════════════════════════════════════════════════════
# ── FLOATING ACCENT PILL & SPARKLES ──
# ════════════════════════════════════════════════════════

# Floating Balance Pill (Between Left and Right)
bal_x = 420 * SCALE
bal_y = 202 * SCALE
bal_w = 160 * SCALE
bal_h = 38 * SCALE
draw_box(bal_x, bal_y, bal_w, bal_h, YELLOW, radius=bal_h//2, shadow_off=(4*SCALE, 4*SCALE))
draw_lightning(bal_x + 20*SCALE, bal_y + bal_h//2, 12*SCALE, 16*SCALE, fill=INK_BLACK, outline=INK_BLACK)
draw.text((bal_x + 36*SCALE, bal_y + 9*SCALE), "1,250 AURA", font=font_body, fill=INK_BLACK)

# Decorative Sparkles (Yellow, Blue, Green - ZERO PURPLE)
draw_sparkle(470*SCALE, 70*SCALE, 14*SCALE, YELLOW)
draw_sparkle(440*SCALE, 430*SCALE, 13*SCALE, CYBER_BLUE)
draw_sparkle(990*SCALE, 220*SCALE, 16*SCALE, GREEN)
draw_sparkle(30*SCALE, 360*SCALE, 14*SCALE, GREEN)
draw_sparkle(995*SCALE, 450*SCALE, 12*SCALE, YELLOW)
draw_sparkle(30*SCALE, 140*SCALE, 10*SCALE, CYBER_BLUE)

# ── DOWNSAMPLE TO 1024 x 500 WITH LANCZOS FOR SUPREME SHARPNESS ──
final_img = img.resize((1024, 500), Image.Resampling.LANCZOS)

out_path1 = "d:/vibe projects/Aura 100/deploy/store/assets/feature_graphic_1024x500.png"
out_path2 = "C:/Users/denis/Desktop/AuraQuest_Store_Bilder/feature_graphic_1024x500.png"
out_brain = "C:/Users/denis/.gemini/antigravity-ide/brain/3c6f15d7-592a-4ff7-9132-4298a1c061e7/feature_graphic_benefits_1024x500.png"

final_img.save(out_path1, "PNG", optimize=True)
final_img.save(out_path2, "PNG", optimize=True)
final_img.save(out_brain, "PNG", optimize=True)

print("SUCCESS: Feature Graphic v2 generated with pure focus on benefits, habits & challenges!")
