from PIL import Image, ImageDraw

im = Image.open(r'C:\Users\denis\.gemini\antigravity-ide\brain\3c6f15d7-592a-4ff7-9132-4298a1c061e7\dueling_bolts_icon_1788529676462.jpg').convert("RGBA")
w, h = im.size
cx, cy = w // 2, h // 2

# We want a seamless dark background that extends to all 4 corners so Google Play squircle mask looks flawless
# The dark border of the circle is around radius R=488.
# Let's create a new image with the dark border color
DARK_BG = (28, 32, 38, 255) # Sleek graphite/obsidian matching the outer ring

new_img = Image.new("RGBA", (w, h), DARK_BG)

# Create a circular mask for the inner circle
mask = Image.new("L", (w, h), 0)
mask_draw = ImageDraw.Draw(mask)
# Mask radius just inside the white corners
R = 485
mask_draw.ellipse([cx - R, cy - R, cx + R, cy + R], fill=255)

# Smooth the edge of the mask slightly
from PIL import ImageFilter
mask = mask.filter(ImageFilter.GaussianBlur(1.5))

# Composite the image onto the seamless dark background
new_img.paste(im, (0, 0), mask)

# Also draw a subtle matching outer frame or keep it clean
# Now resize to 512 x 512 with high quality Lanczos
icon_512 = new_img.resize((512, 512), Image.Resampling.LANCZOS).convert("RGB")

out_desktop = r"C:\Users\denis\Desktop\AuraQuest_Store_Bilder\icon_512.png"
out_project = r"d:\vibe projects\Aura 100\deploy\store\assets\icon_512.png"
out_brain = r"C:\Users\denis\.gemini\antigravity-ide\brain\3c6f15d7-592a-4ff7-9132-4298a1c061e7\icon_512_clash_pro.png"

icon_512.save(out_desktop, "PNG", optimize=True)
icon_512.save(out_project, "PNG", optimize=True)
icon_512.save(out_brain, "PNG", optimize=True)

print("Icon 512 successfully created with seamless dark background!")
