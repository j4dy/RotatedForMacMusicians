import os
import sys
from PIL import Image

def make_icns(source_png, output_icns):
    iconset_dir = "AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        ("16x16", 16),
        ("16x16@2x", 32),
        ("32x32", 32),
        ("32x32@2x", 64),
        ("128x128", 128),
        ("128x128@2x", 256),
        ("256x256", 256),
        ("256x256@2x", 512),
        ("512x512", 512),
        ("512x512@2x", 1024)
    ]
    
    img = Image.open(source_png)
    for name, size in sizes:
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, f"icon_{name}.png"))
        
    os.system(f"iconutil -c icns {iconset_dir}")
    # clean up iconset folder
    os.system(f"rm -rf {iconset_dir}")
    print(f"Generated {output_icns} successfully.")

if __name__ == "__main__":
    make_icns("docs/favicon.png", "AppIcon.icns")
