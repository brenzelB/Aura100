from PIL import Image, ImageDraw, ImageFilter
import os

# Paths
brain_dir = r"C:\Users\denis\.gemini\antigravity-ide\brain\3c6f15d7-592a-4ff7-9132-4298a1c061e7"
desktop_dir = r"C:\Users\denis\Desktop\AuraQuest_Store_Bilder"
deploy_dir = r"d:\vibe projects\Aura 100\deploy\store\assets"

lightning_src = os.path.join(brain_dir, "trophy_lightning_icon_1788530576635.jpg")
star_src = os.path.join(brain_dir, "trophy_app_icon_1788530557251.jpg")

# 1. Finalize Lightning Trophy Icon (Primary icon_512.png)
im_lightning = Image.open(lightning_src).convert("RGB")
# Downsample to 512 x 512 with Lanczos
icon_lightning_512 = im_lightning.resize((512, 512), Image.Resampling.LANCZOS)

out_lightning_desktop = os.path.join(desktop_dir, "icon_512.png")
out_lightning_deploy = os.path.join(deploy_dir, "icon_512.png")
icon_lightning_512.save(out_lightning_desktop, "PNG", optimize=True)
icon_lightning_512.save(out_lightning_deploy, "PNG", optimize=True)
print("Saved primary icon_512.png (Gold Trophy with Lightning Crest)!")

# 2. Finalize Star Trophy Icon (Alternative icon_512_trophy_star.png)
im_star = Image.open(star_src).convert("RGBA")
w, h = im_star.size
# Dark background matching inner dark area
DARK_BG = (18, 20, 25, 255)
star_composite = Image.new("RGBA", (w, h), DARK_BG)

# Create squircle/circle mask to eliminate white outer corners
mask = Image.new("L", (w, h), 0)
mdraw = ImageDraw.Draw(mask)
# Inset radius from 1024
mdraw.rounded_rectangle([30, 30, w - 30, h - 30], radius=180, fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(2))

star_composite.paste(im_star, (0, 0), mask)
icon_star_512 = star_composite.resize((512, 512), Image.Resampling.LANCZOS).convert("RGB")

out_star_desktop = os.path.join(desktop_dir, "icon_512_trophy_star.png")
out_star_deploy = os.path.join(deploy_dir, "icon_512_trophy_star.png")
icon_star_512.save(out_star_desktop, "PNG", optimize=True)
icon_star_512.save(out_star_deploy, "PNG", optimize=True)
print("Saved alternative icon_512_trophy_star.png (Gold Trophy with Star Crest)!")
