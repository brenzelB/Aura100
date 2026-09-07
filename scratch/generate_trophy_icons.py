import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 2048  # 4x supersampling for ultra-crisp vector rendering
TARGET_SIZE = 512

def create_trophy_icon(bg_style="dark", with_lightning_badge=True):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = SIZE // 2
    cy = SIZE // 2
    
    # ── 1. BACKGROUND ──
    if bg_style == "dark":
        # Deep luxury obsidian / charcoal
        bg_col = (19, 21, 26, 255)
        # Gradient or solid with subtle radial aura
        bg = Image.new("RGBA", (SIZE, SIZE), bg_col)
        
        # Subtle warm gold radial glow behind the trophy
        glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        gdraw = ImageDraw.Draw(glow)
        for r in range(700, 100, -30):
            alpha = int(18 * (1.0 - r / 700.0))
            gdraw.ellipse([cx - r, cy - 80 - r, cx + r, cy - 80 + r], fill=(255, 190, 0, alpha))
        glow = glow.filter(ImageFilter.GaussianBlur(40))
        bg = Image.alpha_composite(bg, glow)
        
        # Subtle rim border
        bg_draw = ImageDraw.Draw(bg)
        # Google Play icons are full bleed squares (Google applies squircle mask automatically)
        outline_col = (25, 25, 30)
        
    elif bg_style == "cream":
        # App's signature warm cream
        bg_col = (253, 251, 247, 255)
        bg = Image.new("RGBA", (SIZE, SIZE), bg_col)
        # Subtle grid dots
        bg_draw = ImageDraw.Draw(bg)
        dot_spacing = 64
        dot_r = 4
        for x in range(dot_spacing // 2, SIZE, dot_spacing):
            for y in range(dot_spacing // 2, SIZE, dot_spacing):
                bg_draw.ellipse([x - dot_r, y - dot_r, x + dot_r, y + dot_r], fill=(230, 225, 215, 255))
        outline_col = (20, 21, 25)
        
    elif bg_style == "royal_blue":
        # Deep energetic midnight blue
        bg_col = (10, 18, 36, 255)
        bg = Image.new("RGBA", (SIZE, SIZE), bg_col)
        glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        gdraw = ImageDraw.Draw(glow)
        for r in range(650, 80, -25):
            alpha = int(24 * (1.0 - r / 650.0))
            gdraw.ellipse([cx - r, cy - 60 - r, cx + r, cy - 60 + r], fill=(0, 140, 255, alpha))
        glow = glow.filter(ImageFilter.GaussianBlur(35))
        bg = Image.alpha_composite(bg, glow)
        outline_col = (15, 25, 45)

    # ── 2. TROPHY GEOMETRY ──
    # Palette
    GOLD_LIGHT = (255, 235, 120)     # Highlight
    GOLD_MAIN = (255, 199, 0)        # Core Gold
    GOLD_SHADE = (220, 150, 0)       # Mid shade
    GOLD_DARK = (180, 110, 0)        # Deep shadow
    GOLD_EXTRA_DARK = (130, 75, 0)   # Pedestal shadow
    INK = (20, 21, 25)               # Bold outlines
    WHITE = (255, 255, 255)
    
    # Layer for Trophy with Drop Shadow
    trophy_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tdraw = ImageDraw.Draw(trophy_layer)
    
    # Vertical coordinates
    cup_top_y = cy - 440
    cup_rim_h = 100
    cup_rim_w = 640
    cup_body_h = 460
    cup_bottom_w = 260
    stem_top_y = cup_top_y + cup_body_h
    stem_h = 140
    stem_w = 110
    base_top_y = stem_top_y + stem_h
    base_h = 240
    base_w = 580
    
    # 2.1 Handles (Left & Right)
    # Handles are big glorious curved wings
    handle_outer_w = 980
    handle_h = 480
    handle_y = cup_top_y + 40
    handle_thick = 90
    
    # Outer handles polygon/arcs
    # We construct smooth bezier or layered polygon arcs for the handles
    def draw_handle(side="left"):
        sign = -1 if side == "left" else 1
        
        # Outer curve points
        pts_outer = []
        # Inner curve points
        pts_inner = []
        steps = 40
        for i in range(steps + 1):
            t = i / steps
            # Parametric curve for handle
            # y goes from 0 to 1
            cur_y = handle_y + t * handle_h
            # width arches out then comes back into the cup
            arch = math.sin(t * math.pi) ** 0.85
            out_x = cx + sign * (cup_rim_w // 2 - 40 + arch * (handle_outer_w // 2 - cup_rim_w // 2 + 40))
            in_x = out_x - sign * handle_thick
            pts_outer.append((out_x, cur_y))
            pts_inner.append((in_x, cur_y))
            
        handle_poly = pts_outer + list(reversed(pts_inner))
        
        # Draw shadow first if dark mode / outline
        tdraw.polygon(handle_poly, fill=GOLD_SHADE if side == "right" else GOLD_MAIN, outline=INK)
        
        # Top highlight on left handle
        if side == "left":
            highlight_pts = pts_outer[:steps//2] + list(reversed(pts_inner[:steps//2]))
            tdraw.polygon(highlight_pts, fill=GOLD_LIGHT, outline=INK)

    # Draw Handles
    draw_handle("left")
    draw_handle("right")
    
    # 2.2 Cup Body
    # Smooth tapered cup
    body_steps = 30
    cup_left = []
    cup_right = []
    for i in range(body_steps + 1):
        t = i / body_steps
        cur_y = cup_top_y + cup_rim_h // 2 + t * (cup_body_h - cup_rim_h // 2)
        # curved taper
        factor = (1.0 - t * 0.75 + 0.1 * math.sin(t * math.pi))
        cur_w = (cup_rim_w // 2) * factor
        cup_left.append((cx - cur_w, cur_y))
        cup_right.append((cx + cur_w, cur_y))
    
    # Base connector curve
    cup_bottom_arc = []
    for i in range(20 + 1):
        angle = math.pi - i * (math.pi / 20)
        bx = cx + (cup_bottom_w // 2) * math.cos(angle)
        by = stem_top_y - 20 + 35 * math.sin(angle)
        cup_bottom_arc.append((bx, by))
        
    cup_poly = cup_left + cup_bottom_arc + list(reversed(cup_right))
    
    # Draw base cup body
    tdraw.polygon(cup_poly, fill=GOLD_MAIN, outline=INK)
    
    # Cup Lighting (Left highlight, Right shadow)
    # Split body vertically down center
    cup_right_shade = []
    for pt in cup_right:
        cup_right_shade.append(pt)
    cup_right_shade.append((cx, stem_top_y + 15))
    cup_right_shade.append((cx, cup_top_y + cup_rim_h // 2))
    tdraw.polygon(cup_right_shade, fill=GOLD_SHADE, outline=INK)
    
    # Cup Left Highlight streak
    cup_left_hl = []
    for pt in cup_left[:body_steps//2]:
        cup_left_hl.append((pt[0] + 25, pt[1]))
    cup_left_hl.append((cx - 80, cup_top_y + cup_body_h // 2))
    cup_left_hl.append((cx - 80, cup_top_y + cup_rim_h // 2))
    tdraw.polygon(cup_left_hl, fill=GOLD_LIGHT)

    # 2.3 Cup Rim (Top ellipse)
    rim_rect = [cx - cup_rim_w // 2, cup_top_y, cx + cup_rim_w // 2, cup_top_y + cup_rim_h]
    # Outer gold rim
    tdraw.ellipse(rim_rect, fill=GOLD_LIGHT, outline=INK, width=16)
    # Inner opening (depth)
    inner_rim_rect = [cx - cup_rim_w // 2 + 35, cup_top_y + 18, cx + cup_rim_w // 2 - 35, cup_top_y + cup_rim_h - 18]
    tdraw.ellipse(inner_rim_rect, fill=GOLD_DARK, outline=INK, width=10)

    # 2.4 Stem
    # Tiered stem rings
    # Upper ring
    tdraw.rounded_rectangle([cx - stem_w, stem_top_y - 10, cx + stem_w, stem_top_y + 35], radius=16, fill=GOLD_LIGHT, outline=INK, width=12)
    # Stem column
    stem_poly = [
        (cx - stem_w * 0.7, stem_top_y + 30),
        (cx + stem_w * 0.7, stem_top_y + 30),
        (cx + stem_w * 0.9, base_top_y - 20),
        (cx - stem_w * 0.9, base_top_y - 20)
    ]
    tdraw.polygon(stem_poly, fill=GOLD_SHADE, outline=INK)
    # Stem left highlight
    tdraw.polygon([
        (cx - stem_w * 0.7, stem_top_y + 30),
        (cx - stem_w * 0.1, stem_top_y + 30),
        (cx - stem_w * 0.1, base_top_y - 20),
        (cx - stem_w * 0.9, base_top_y - 20)
    ], fill=GOLD_LIGHT)
    
    # Lower stem ring
    tdraw.rounded_rectangle([cx - stem_w * 1.15, base_top_y - 28, cx + stem_w * 1.15, base_top_y + 15], radius=16, fill=GOLD_MAIN, outline=INK, width=12)

    # 2.5 Championship Base / Pedestal (Layered blocks)
    # Upper gold plate
    p1_w = base_w * 0.75
    p1_h = 50
    p1_y = base_top_y + 10
    tdraw.rounded_rectangle([cx - p1_w // 2, p1_y, cx + p1_w // 2, p1_y + p1_h], radius=18, fill=GOLD_LIGHT, outline=INK, width=14)
    
    # Main Pedestal Block (Dark Obsidian or Rich Mahogany with gold plaque)
    p2_w = base_w
    p2_h = 160
    p2_y = p1_y + p1_h
    pedestal_col = (30, 32, 40) if bg_style != "dark" else (14, 15, 18)
    tdraw.rounded_rectangle([cx - p2_w // 2, p2_y, cx + p2_w // 2, p2_y + p2_h], radius=24, fill=pedestal_col, outline=INK, width=16)
    
    # Base bottom footer plate
    p3_w = base_w + 60
    p3_h = 45
    p3_y = p2_y + p2_h - 15
    tdraw.rounded_rectangle([cx - p3_w // 2, p3_y, cx + p3_w // 2, p3_y + p3_h], radius=16, fill=GOLD_SHADE, outline=INK, width=14)
    tdraw.rounded_rectangle([cx - p3_w // 2 + 15, p3_y + 5, cx, p3_y + p3_h - 5], radius=12, fill=GOLD_LIGHT)

    # Gold Plaque on Pedestal
    plaque_w = base_w * 0.65
    plaque_h = 75
    plaque_y = p2_y + 35
    tdraw.rounded_rectangle([cx - plaque_w // 2, plaque_y, cx + plaque_w // 2, plaque_y + plaque_h], radius=14, fill=GOLD_MAIN, outline=INK, width=10)
    # Plaque screws/rivets
    screw_r = 6
    for sx in [cx - plaque_w // 2 + 18, cx + plaque_w // 2 - 18]:
        tdraw.ellipse([sx - screw_r, plaque_y + plaque_h // 2 - screw_r, sx + screw_r, plaque_y + plaque_h // 2 + screw_r], fill=INK)
    # Inscription lines on plaque
    tdraw.line([(cx - 90, plaque_y + plaque_h // 2 - 10), (cx + 90, plaque_y + plaque_h // 2 - 10)], fill=INK, width=8)
    tdraw.line([(cx - 60, plaque_y + plaque_h // 2 + 10), (cx + 60, plaque_y + plaque_h // 2 + 10)], fill=INK, width=6)

    # ── 3. EMBLEM ON CUP (Lightning or Star) ──
    if with_lightning_badge:
        # A sleek, dynamic Electric Lightning Bolt carved into the cup center
        # or a circular badge with a bold lightning bolt
        badge_r = 130
        badge_cy = cup_top_y + cup_body_h // 2 - 10
        # Circular badge
        tdraw.ellipse([cx - badge_r, badge_cy - badge_r, cx + badge_r, badge_cy + badge_r], fill=INK, outline=WHITE, width=10)
        
        # Electric Bolt inside badge
        bw = 140
        bh = 200
        bolt_pts = [
            (cx + bw * 0.12, badge_cy - bh * 0.46),
            (cx - bw * 0.42, badge_cy + bh * 0.05),
            (cx - bw * 0.05, badge_cy + bh * 0.05),
            (cx - bw * 0.28, badge_cy + bh * 0.48),
            (cx + bw * 0.42, badge_cy - bh * 0.05),
            (cx + bw * 0.06, badge_cy - bh * 0.05),
        ]
        # Bolt fill: Electric Cyan/Blue or Glowing White/Yellow
        tdraw.polygon(bolt_pts, fill=(0, 220, 255) if bg_style == "dark" else GOLD_MAIN, outline=WHITE, width=6)
    
    # ── 4. SPARKLES & STARS AROUND CUP ──
    def draw_sparkle(scx, scy, r, col=WHITE):
        r_in = r * 0.22
        points = []
        for i in range(8):
            angle = i * (math.pi / 4)
            dist = r if i % 2 == 0 else r_in
            points.append((scx + dist * math.cos(angle), scy + dist * math.sin(angle)))
        tdraw.polygon(points, fill=col, outline=INK, width=8)

    draw_sparkle(cx - 480, cup_top_y + 40, 70, GOLD_LIGHT)
    draw_sparkle(cx + 490, cup_top_y + 80, 60, (0, 220, 255) if bg_style != "cream" else GOLD_LIGHT)
    draw_sparkle(cx - 440, cup_top_y + 460, 50, (0, 220, 255) if bg_style != "cream" else GOLD_MAIN)
    draw_sparkle(cx + 470, cup_top_y + 420, 75, GOLD_LIGHT)
    
    # Rim highlight flash
    draw_sparkle(cx - 240, cup_top_y + 20, 45, WHITE)

    # ── 5. COMPOSITE WITH DROP SHADOW ──
    # For Neo-Brutalist Cream mode, draw a bold offset shadow
    if bg_style == "cream":
        shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        sdraw = ImageDraw.Draw(shadow)
        # Extract alpha from trophy layer and offset
        s_alpha = trophy_layer.split()[3]
        shadow_img = Image.new("RGBA", (SIZE, SIZE), (20, 21, 25, 255))
        shadow_mask = Image.new("L", (SIZE, SIZE), 0)
        shadow_mask.paste(s_alpha, (36, 36))
        bg.paste(shadow_img, (0, 0), shadow_mask)

    # Paste trophy onto background
    bg.paste(trophy_layer, (0, 0), trophy_layer)
    
    # Downsample to 512 x 512 with high-grade Lanczos
    final_icon = bg.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS).convert("RGB")
    return final_icon

# Generate 3 styles to test
icon_dark = create_trophy_icon("dark", True)
icon_cream = create_trophy_icon("cream", True)
icon_blue = create_trophy_icon("royal_blue", True)

icon_dark.save(r"d:\vibe projects\Aura 100\deploy\store\assets\icon_trophy_dark.png", "PNG", optimize=True)
icon_cream.save(r"d:\vibe projects\Aura 100\deploy\store\assets\icon_trophy_cream.png", "PNG", optimize=True)
icon_blue.save(r"d:\vibe projects\Aura 100\deploy\store\assets\icon_trophy_blue.png", "PNG", optimize=True)

print("Trophy icons generated successfully!")
