from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math

OUT = os.path.dirname(os.path.abspath(__file__))

VIOLET = (124, 108, 240)
VIOLET_DEEP = (76, 58, 227)
CYAN = (79, 214, 236)
BG_DARK = (17, 15, 26)
BG_DARK2 = (24, 21, 38)
TEXT = (240, 238, 250)
DIM = (168, 163, 190)
WHITE = (255, 255, 255)
GREEN = (110, 214, 160)
AMBER = (240, 201, 107)

def font(size, bold=False):
    names = ["arialbd.ttf"] if bold else ["arial.ttf"]
    for n in names:
        for base in ["C:/Windows/Fonts/", ""]:
            try:
                return ImageFont.truetype(base + n, size)
            except Exception:
                continue
    return ImageFont.load_default()

def centered_text(draw, box, text, fnt, color):
    x0, y0, x1, y1 = box
    bbox = draw.textbbox((0, 0), text, font=fnt)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    cx = x0 + (x1 - x0 - w) / 2 - bbox[0]
    cy = y0 + (y1 - y0 - h) / 2 - bbox[1]
    draw.text((cx, cy), text, font=fnt, fill=color)

def rounded(draw, xy, fill=None, outline=None, radius=16, width=2):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

# ============================================================
# 1) BANNER principal (topo do README)
# ============================================================
W, H = 1600, 420
img = Image.new("RGB", (W, H), BG_DARK)
d = ImageDraw.Draw(img, "RGBA")

# glow radial simulando nebulosa no canto direito
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r, alpha in [(700, 10), (550, 16), (400, 22), (260, 30), (150, 40)]:
    gd.ellipse([W - 500 - r, H // 2 - r, W - 500 + r, H // 2 + r], fill=(*VIOLET, alpha))
for r, alpha in [(400, 14), (280, 20), (160, 28)]:
    gd.ellipse([W - 260 - r, H // 2 - 40 - r, W - 260 + r, H // 2 - 40 + r], fill=(*CYAN, alpha))
glow = glow.filter(ImageFilter.GaussianBlur(40))
img.paste(glow, (0, 0), glow)
d = ImageDraw.Draw(img, "RGBA")

# pontos de "estrelas"
import random
random.seed(7)
for _ in range(140):
    x = random.randint(0, W)
    y = random.randint(0, H)
    r = random.choice([1, 1, 1, 2])
    a = random.randint(40, 160)
    d.ellipse([x, y, x + r, y + r], fill=(255, 255, 255, a))

# orbitas / nós (remete ao logo descrito na identidade visual)
cx, cy = W - 340, H // 2 - 10
d.ellipse([cx - 46, cy - 46, cx + 46, cy + 46], outline=(*CYAN, 160), width=2)
d.ellipse([cx - 120, cy - 80, cx + 120, cy + 80], outline=(*VIOLET, 110), width=2)
d.ellipse([cx - 190, cy - 40, cx + 190, cy + 40], outline=(*VIOLET, 70), width=2)
core = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
cd = ImageDraw.Draw(core)
cd.ellipse([10, 10, 130, 130], fill=(*VIOLET_DEEP, 255))
core = core.filter(ImageFilter.GaussianBlur(6))
img.paste(core, (cx - 70, cy - 70), core)
d = ImageDraw.Draw(img, "RGBA")
for ang, rad in [(20, 190), (160, 120), (260, 80)]:
    nx = cx + rad * math.cos(math.radians(ang))
    ny = cy + rad * 0.42 * math.sin(math.radians(ang))
    d.ellipse([nx - 6, ny - 6, nx + 6, ny + 6], fill=(*CYAN, 230))

# textos
f_kicker = font(24, bold=True)
f_title = font(64, bold=True)
f_sub = font(26)
pad = 90
d.text((pad, 110), "NEBULA HOST  ·  ESTUDO DE CASO TÉCNICO", font=f_kicker, fill=(*CYAN, 255))
d.text((pad, 155), "Chatbot de Atendimento", font=f_title, fill=(*WHITE, 255))
d.text((pad, 228), "via WhatsApp", font=f_title, fill=(*WHITE, 255))
d.text((pad, 312), "Arquitetura, decisões de engenharia e achados reais sobre a", font=f_sub, fill=(*DIM, 255))
d.text((pad, 348), "WhatsApp Cloud API — documentados como referência técnica aberta.", font=f_sub, fill=(*DIM, 255))

img.save(os.path.join(OUT, "banner.png"))

# ============================================================
# 2) Cartões de "achados em destaque" (grid 2x2, pra usar no README)
# ============================================================
W2, H2 = 1600, 620
img2 = Image.new("RGB", (W2, H2), (250, 249, 252))
d2 = ImageDraw.Draw(img2)

findings = [
    ("01", "Inscrição invisível", "A WABA precisa ser inscrita no App via API — não aparece no checklist do painel guiado.", VIOLET_DEEP, (238, 235, 252)),
    ("02", "Primeira mensagem \"perdida\"", "A 1ª mensagem de um contato após habilitar coexistência não dispara webhook — comportamento esperado da Meta.", (14, 159, 181), (222, 246, 250)),
    ("03", "Duas camadas, um número", "Status da API pode cair sem afetar o WhatsApp comum — são conexões independentes no mesmo número.", (196, 130, 20), (253, 240, 220)),
    ("04", "Sem botão de reconectar", "Números em coexistência (SMB) não têm reconexão manual — nem via painel, nem via API. É automática.", (39, 107, 69), (233, 246, 238)),
]

card_w, card_h = 740, 260
gap = 40
x_start = (W2 - (card_w * 2 + gap)) // 2
y_start = 40

f_num = font(46, bold=True)
f_h = font(28, bold=True)
f_body = font(19)

for idx, (num, title, body, accent, bg) in enumerate(findings):
    col = idx % 2
    row = idx // 2
    x0 = x_start + col * (card_w + gap)
    y0 = y_start + row * (card_h + gap)
    x1, y1 = x0 + card_w, y0 + card_h
    rounded(d2, [x0, y0, x1, y1], fill=bg, radius=22)
    d2.rectangle([x0, y0, x0 + 10, y1], fill=accent)
    d2.text((x0 + 40, y0 + 28), num, font=f_num, fill=(*accent, 255) if len(accent) == 4 else accent)
    d2.text((x0 + 150, y0 + 38), title, font=f_h, fill=(30, 28, 40))
    # word-wrap body
    words = body.split(" ")
    lines, cur = [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if d2.textbbox((0, 0), test, font=f_body)[2] > card_w - 80:
            lines.append(cur)
            cur = w
        else:
            cur = test
    if cur:
        lines.append(cur)
    yy = y0 + 110
    for line in lines:
        d2.text((x0 + 40, yy), line, font=f_body, fill=(70, 66, 84))
        yy += 30

img2.save(os.path.join(OUT, "achados-destaque.png"))

print("done")
