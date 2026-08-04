# Generates the launcher icon: a stylized California poppy on deep pine.
# assets/icon/icon.png     — full-bleed legacy icon
# assets/icon/icon_fg.png  — transparent adaptive-icon foreground (safe zone)
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024
PINE = (46, 83, 57, 255)
PINE_DARK = (29, 53, 38, 255)
PETAL = (232, 89, 12, 255)
PETAL_HI = (245, 122, 40, 255)
CENTER = (61, 36, 16, 255)
GOLD = (233, 180, 76, 255)


def petal_layer(size, w, h, color):
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = size // 2
    # petal: ellipse whose base sits at the flower center, tip pointing up
    d.ellipse([cx - w // 2, size // 2 - h, cx + w // 2, size // 2 + int(h * 0.08)],
              fill=color)
    return layer


def bloom(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    n = 5
    w, h = int(size * 0.40), int(size * 0.46)
    for i in range(n):
        color = PETAL_HI if i % 2 else PETAL
        p = petal_layer(size, w, h, color)
        p = p.rotate(i * (360 / n), center=(size // 2, size // 2),
                     resample=Image.BICUBIC)
        img = Image.alpha_composite(img, p)
    d = ImageDraw.Draw(img)
    cx = size // 2
    r = int(size * 0.115)
    d.ellipse([cx - r, cx - r, cx + r, cx + r], fill=CENTER)
    # ring of gold stamen dots
    for i in range(10):
        a = i * math.tau / 10
        x = cx + math.cos(a) * r * 0.62
        y = cx + math.sin(a) * r * 0.62
        dr = int(size * 0.013)
        d.ellipse([x - dr, y - dr, x + dr, y + dr], fill=GOLD)
    return img


# ---- full icon: pine gradient background + bloom ----
bg = Image.new('RGBA', (S, S), PINE)
grad = Image.new('L', (S, S), 0)
gd = ImageDraw.Draw(grad)
for y in range(S):
    gd.line([(0, y), (S, y)], fill=int(90 * y / S))
bg = Image.composite(Image.new('RGBA', (S, S), PINE_DARK), bg, grad)

# soft vignette highlight behind the bloom
glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
gd2 = ImageDraw.Draw(glow)
gd2.ellipse([S * 0.18, S * 0.18, S * 0.82, S * 0.82],
            fill=(255, 235, 200, 40))
glow = glow.filter(ImageFilter.GaussianBlur(60))
bg = Image.alpha_composite(bg, glow)

full = Image.alpha_composite(bg, bloom(S))
full.save('assets/icon/icon.png')

# ---- adaptive foreground: bloom only, shrunk into the safe zone ----
fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
small = bloom(int(S * 0.62)).resize((int(S * 0.62), int(S * 0.62)),
                                    Image.LANCZOS)
off = (S - small.width) // 2
fg.paste(small, (off, off), small)
fg.save('assets/icon/icon_fg.png')
print('icons written')
