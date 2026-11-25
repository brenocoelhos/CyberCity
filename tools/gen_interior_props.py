#!/usr/bin/env python3
"""Gera os móveis sci-fi dos interiores em pixel art (PNG com transparência).

Uso (na pasta do projeto):  python3 tools/gen_interior_props.py
Precisa do Pillow (pip install pillow). Saída: assets/environment/interior/props/

Cada objeto é desenhado com 2 pixels de textura por unidade do mapa; no Godot o
Sprite2D usa scale 0.5 e filtro Nearest (sem suavização), então 1 objeto de
64×64 px ocupa 32×32 do mapa (uma unidade). Paleta igual à das paredes:
metal cinza-azulado com contorno escuro, luzes ciano e detalhes magenta.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "environment", "interior", "props")

# Paleta
OUTLINE = (10, 13, 20, 255)
METAL_D = (30, 37, 52, 255)
METAL = (48, 58, 78, 255)
METAL_L = (72, 86, 112, 255)
METAL_H = (104, 120, 150, 255)
SCREEN_D = (6, 22, 44, 255)
CYAN = (60, 220, 255, 255)
CYAN_D = (20, 120, 170, 255)
CYAN_H = (190, 250, 255, 255)
MAGENTA = (255, 70, 200, 255)
MAGENTA_D = (150, 30, 120, 255)
GREEN = (60, 230, 140, 255)
LEAF_D = (24, 82, 52, 255)
LEAF = (40, 130, 70, 255)
LEAF_L = (90, 190, 100, 255)
WOOD = (92, 64, 50, 255)
FABRIC_D = (28, 30, 48, 255)
FABRIC = (44, 48, 74, 255)
FABRIC_L = (66, 72, 108, 255)
PURPLE = (150, 90, 255, 255)
PURPLE_L = (210, 170, 255, 255)

random.seed(7)


def new(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def box(d, x0, y0, x1, y1, fill, outline=OUTLINE, light=None, dark=None):
    """Retângulo com contorno e bisel (luz em cima/esquerda, sombra embaixo)."""
    d.rectangle([x0, y0, x1, y1], fill=outline)
    d.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], fill=fill)
    if light:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=light)
        d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 1], fill=light)
    if dark:
        d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=dark)
        d.line([x1 - 1, y0 + 1, x1 - 1, y1 - 1], fill=dark)


def glow(img, x0, y0, x1, y1, color, radius=4, strength=90):
    """Halo de luz (borda suave) em volta de um retângulo."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for r in range(radius, 0, -1):
        a = int(strength * (1 - r / (radius + 1)) ** 2)
        ld.rectangle([x0 - r, y0 - r, x1 + r, y1 + r], fill=color[:3] + (a,))
    img.alpha_composite(layer)


def screen(d, x0, y0, x1, y1, kind="lines"):
    box(d, x0, y0, x1, y1, SCREEN_D)
    w = x1 - x0
    if kind == "lines":
        for i, y in enumerate(range(y0 + 3, y1 - 2, 3)):
            ln = int((w - 6) * (0.4 + 0.6 * ((i * 37) % 10) / 10))
            d.line([x0 + 3, y, x0 + 3 + ln, y], fill=CYAN if i % 3 else CYAN_D)
    elif kind == "graph":
        pts = [(x0 + 3 + i * (w - 6) / 7, y1 - 4 - (math.sin(i * 1.3) + 1) * (y1 - y0 - 8) / 2.4) for i in range(8)]
        d.line(pts, fill=GREEN, width=1)
        d.line([x0 + 3, y1 - 3, x1 - 3, y1 - 3], fill=CYAN_D)
    elif kind == "planet":
        cx, cy, r = (x0 + x1) / 2, (y0 + y1) / 2, min(w, y1 - y0) / 3
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CYAN_D, outline=CYAN)
        d.arc([cx - r * 1.7, cy - r * 0.5, cx + r * 1.7, cy + r * 0.5], 200, 340, fill=CYAN_H)
        d.arc([cx - r * 1.7, cy - r * 0.5, cx + r * 1.7, cy + r * 0.5], 20, 160, fill=CYAN_H)
    elif kind == "dna":
        for i in range(x0 + 4, x1 - 3, 2):
            t = (i - x0) / 6.0
            ya = (y0 + y1) / 2 + math.sin(t) * (y1 - y0) / 3.5
            yb = (y0 + y1) / 2 - math.sin(t) * (y1 - y0) / 3.5
            d.point((i, ya), fill=CYAN_H)
            d.point((i, yb), fill=MAGENTA)
            if i % 6 == 0:
                d.line([i, ya, i, yb], fill=CYAN_D)


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))


# --- Objetos -------------------------------------------------------------------

def plant():
    img, d = new(36, 64)
    # vaso sci-fi
    box(d, 6, 40, 29, 62, METAL, light=METAL_H, dark=METAL_D)
    d.line([8, 46, 27, 46], fill=CYAN)
    glow(img, 8, 46, 27, 46, CYAN, 2, 60)
    d = ImageDraw.Draw(img)
    d.rectangle([7, 38, 28, 41], fill=OUTLINE)
    d.rectangle([8, 39, 27, 40], fill=(40, 28, 22, 255))
    # folhas
    for _ in range(46):
        a = random.uniform(math.pi * 1.05, math.pi * 1.95)
        r = random.uniform(6, 22)
        x = 18 + math.cos(a) * r * 0.8
        y = 38 + math.sin(a) * r * 1.4
        c = random.choice([LEAF_D, LEAF, LEAF, LEAF_L])
        d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=c, outline=OUTLINE if random.random() < 0.3 else None)
    return img


def wall_screen(kind, w=128, h=56):
    img, d = new(w, h)
    glow(img, 4, 4, w - 5, h - 5, CYAN, 4, 70)
    d = ImageDraw.Draw(img)
    box(d, 3, 3, w - 4, h - 4, METAL_D, light=METAL_L, dark=OUTLINE)
    if kind == "triple":
        third = (w - 14) // 3
        for i, k in enumerate(["planet", "lines", "graph"]):
            screen(d, 7 + i * (third + 1), 7, 7 + i * (third + 1) + third - 1, h - 8, k)
    else:
        screen(d, 7, 7, w - 8, h - 8, kind)
    d.line([w // 2 - 8, h - 5, w // 2 + 8, h - 5], fill=MAGENTA)
    return img


def poster():
    img, d = new(40, 56)
    glow(img, 3, 3, 36, 52, MAGENTA, 3, 60)
    d = ImageDraw.Draw(img)
    box(d, 2, 2, 37, 53, METAL_D, light=METAL_L)
    d.rectangle([6, 6, 33, 49], fill=(26, 10, 40, 255))
    # olho/emblema neon
    d.ellipse([10, 16, 29, 36], outline=MAGENTA)
    d.ellipse([16, 22, 23, 30], fill=CYAN)
    d.line([8, 42, 31, 42], fill=PURPLE)
    d.line([12, 45, 27, 45], fill=MAGENTA_D)
    return img


def vending():
    img, d = new(60, 104)
    box(d, 2, 2, 57, 101, METAL, light=METAL_H, dark=METAL_D)
    glow(img, 8, 10, 38, 70, CYAN, 3, 60)
    d = ImageDraw.Draw(img)
    box(d, 7, 9, 39, 72, SCREEN_D)
    colors = [MAGENTA, CYAN, GREEN, (255, 200, 60, 255), PURPLE]
    for row in range(5):
        y = 14 + row * 11
        d.line([10, y + 7, 36, y + 7], fill=METAL_L)
        for col in range(4):
            x = 11 + col * 7
            d.rectangle([x, y, x + 4, y + 6], fill=colors[(row + col) % 5], outline=OUTLINE)
    box(d, 43, 10, 53, 40, METAL_D)
    for i in range(3):
        d.rectangle([46, 14 + i * 7, 50, 18 + i * 7], fill=CYAN if i != 1 else MAGENTA)
    d.rectangle([44, 46, 52, 52], fill=OUTLINE)
    box(d, 7, 78, 39, 94, METAL_D)
    d.line([4, 6, 55, 6], fill=MAGENTA)
    return img


def sofa(w=96, h=56):
    img, d = new(w, h)
    box(d, 2, 4, w - 3, 30, FABRIC, light=FABRIC_L, dark=FABRIC_D)  # encosto
    box(d, 2, 22, 16, h - 6, FABRIC_D, light=FABRIC)  # braço esq
    box(d, w - 17, 22, w - 3, h - 6, FABRIC_D, light=FABRIC)  # braço dir
    half = (w - 34) // 2
    for i in range(2):
        x = 16 + i * half
        box(d, x, 26, x + half, h - 8, FABRIC_L, light=(96, 104, 150, 255), dark=FABRIC)
    d.line([4, h - 5, w - 5, h - 5], fill=CYAN)
    d.rectangle([6, h - 4, 10, h - 2], fill=OUTLINE)
    d.rectangle([w - 11, h - 4, w - 7, h - 2], fill=OUTLINE)
    return img


def armchair():
    img, d = new(52, 52)
    box(d, 4, 2, 47, 26, FABRIC, light=FABRIC_L, dark=FABRIC_D)
    box(d, 2, 18, 12, 46, FABRIC_D, light=FABRIC)
    box(d, 39, 18, 49, 46, FABRIC_D, light=FABRIC)
    box(d, 12, 24, 39, 44, FABRIC_L, light=(96, 104, 150, 255), dark=FABRIC)
    d.line([4, 48, 47, 48], fill=MAGENTA)
    return img


def hologram():
    img, d = new(128, 120)
    # base circular em perspectiva
    d.ellipse([6, 70, 121, 116], fill=OUTLINE)
    d.ellipse([8, 72, 119, 112], fill=METAL_D)
    d.ellipse([16, 66, 111, 104], fill=OUTLINE)
    d.ellipse([18, 68, 109, 102], fill=METAL)
    d.ellipse([22, 70, 105, 96], fill=METAL_L)
    d.ellipse([34, 74, 93, 92], fill=CYAN_D, outline=CYAN)
    for a in range(0, 360, 30):
        x = 63 + math.cos(math.radians(a)) * 52
        y = 92 + math.sin(math.radians(a)) * 18
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=CYAN if a % 60 else MAGENTA)
    # feixe de luz
    beam = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(beam)
    for i in range(30):
        a = int(70 * (1 - i / 30))
        bd.polygon([(40 + i * 0.3, 84), (87 - i * 0.3, 84), (82, 30), (45, 30)], fill=(60, 220, 255, a // 3))
    img.alpha_composite(beam)
    return img


def holo_globe():
    """Globo do holograma (separado, para pulsar no jogo)."""
    img, d = new(64, 64)
    glow(img, 14, 14, 49, 49, CYAN, 12, 70)
    d = ImageDraw.Draw(img)
    d.ellipse([12, 12, 51, 51], fill=(30, 120, 200, 210), outline=CYAN_H)
    for k in range(1, 4):
        d.arc([12, 31 - k * 5, 51, 32 + k * 5], 0, 360, fill=CYAN)
    d.arc([22, 12, 41, 51], 0, 360, fill=CYAN)
    d.line([31, 12, 31, 51], fill=CYAN)
    d.ellipse([18, 18, 26, 24], fill=CYAN_H)
    return img


def rack():
    img, d = new(48, 100)
    box(d, 2, 2, 45, 97, METAL_D, light=METAL_L, dark=OUTLINE)
    for i in range(8):
        y = 8 + i * 11
        box(d, 6, y, 41, y + 8, METAL, light=METAL_L)
        for j in range(4):
            d.point((10 + j * 3, y + 4), fill=GREEN if (i + j) % 3 else CYAN)
        d.line([24, y + 4, 37, y + 4], fill=OUTLINE)
        d.point((38, y + 3), fill=MAGENTA if i % 2 else CYAN)
    return img


def shelf():
    img, d = new(60, 88)
    box(d, 2, 2, 57, 85, METAL_D, light=METAL_L, dark=OUTLINE)
    for i in range(4):
        y = 8 + i * 19
        d.rectangle([6, y + 15, 53, y + 17], fill=METAL_L)
        x = 7
        while x < 50:
            w = random.randint(3, 6)
            h = random.randint(9, 14)
            c = random.choice([CYAN_D, MAGENTA_D, (80, 60, 140, 255), (40, 100, 90, 255), (120, 90, 40, 255)])
            d.rectangle([x, y + 15 - h, x + w - 1, y + 14], fill=c, outline=OUTLINE)
            x += w + 1
    d.line([4, 4, 55, 4], fill=CYAN)
    return img


def workstation():
    img, d = new(80, 60)
    # mesa
    box(d, 2, 30, 77, 44, METAL, light=METAL_H, dark=METAL_D)
    d.line([4, 43, 75, 43], fill=CYAN)
    box(d, 6, 44, 12, 58, METAL_D)
    box(d, 67, 44, 73, 58, METAL_D)
    # monitores
    for x0 in (10, 42):
        glow(img, x0, 4, x0 + 27, 24, CYAN, 3, 50)
        d = ImageDraw.Draw(img)
        box(d, x0, 3, x0 + 28, 25, METAL_D)
        screen(d, x0 + 2, 5, x0 + 26, 23, "lines" if x0 == 10 else "graph")
        d.rectangle([x0 + 12, 26, x0 + 16, 30], fill=OUTLINE)
    # teclado
    box(d, 24, 32, 54, 37, METAL_D)
    for k in range(26, 52, 3):
        d.point((k, 34), fill=CYAN_D)
    return img


def tube(big=False):
    w, h = (64, 132) if big else (44, 104)
    img, d = new(w, h)
    box(d, 2, h - 18, w - 3, h - 3, METAL, light=METAL_H, dark=METAL_D)
    box(d, 2, 2, w - 3, 14, METAL, light=METAL_H, dark=METAL_D)
    d.line([4, h - 10, w - 5, h - 10], fill=CYAN)
    glow(img, 6, 15, w - 7, h - 19, CYAN, 4, 70)
    glass = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    gd.rectangle([6, 15, w - 7, h - 19], fill=(40, 170, 230, 150))
    gd.rectangle([8, 17, 11, h - 21], fill=(200, 250, 255, 90))
    img.alpha_composite(glass)
    d = ImageDraw.Draw(img)
    d.rectangle([5, 14, w - 6, h - 18], outline=CYAN)
    if big:
        # silhueta de um "espécime"
        cx = w // 2
        d.ellipse([cx - 7, 34, cx + 7, 48], fill=(20, 60, 110, 220))
        d.rectangle([cx - 9, 48, cx + 9, 86], fill=(20, 60, 110, 220))
        d.rectangle([cx - 6, 86, cx + 6, 106], fill=(20, 60, 110, 220))
    for _ in range(10):
        x = random.randint(9, w - 10)
        y = random.randint(20, h - 24)
        d.ellipse([x, y, x + 2, y + 2], outline=CYAN_H)
    return img


def lab_bench():
    img, d = new(104, 60)
    box(d, 2, 22, 101, 36, METAL, light=METAL_H, dark=METAL_D)
    d.line([4, 35, 99, 35], fill=CYAN)
    box(d, 6, 36, 14, 58, METAL_D)
    box(d, 89, 36, 97, 58, METAL_D)
    for i, c in enumerate([CYAN, MAGENTA, GREEN, PURPLE]):
        x = 12 + i * 14
        d.rectangle([x + 2, 6, x + 5, 12], fill=(170, 200, 220, 255), outline=OUTLINE)
        d.polygon([(x, 22), (x + 7, 22), (x + 5, 12), (x + 2, 12)], fill=c, outline=OUTLINE)
    glow(img, 66, 4, 96, 20, CYAN, 2, 50)
    d = ImageDraw.Draw(img)
    box(d, 66, 3, 96, 21, METAL_D)
    screen(d, 68, 5, 94, 19, "dna")
    return img


def crystals():
    img, d = new(48, 32)
    glow(img, 10, 8, 38, 28, PURPLE, 5, 60)
    d = ImageDraw.Draw(img)
    for x, h in [(10, 18), (18, 26), (27, 20), (34, 14)]:
        d.polygon([(x, 30), (x + 7, 30), (x + 5, 30 - h), (x + 2, 30 - h - 3)], fill=PURPLE, outline=OUTLINE)
        d.line([x + 3, 28, x + 3, 32 - h], fill=PURPLE_L)
    return img


def counter():
    img, d = new(240, 72)
    box(d, 2, 30, 237, 68, METAL, light=METAL_H, dark=METAL_D)
    box(d, 2, 22, 237, 34, METAL_L, light=METAL_H, dark=METAL)
    d.line([4, 60, 235, 60], fill=CYAN)
    glow(img, 4, 60, 235, 60, CYAN, 2, 60)
    d = ImageDraw.Draw(img)
    for i in range(5):
        x = 16 + i * 46
        glow(img, x, 2, x + 26, 18, CYAN, 2, 40)
        d = ImageDraw.Draw(img)
        box(d, x, 1, x + 26, 19, METAL_D)
        screen(d, x + 2, 3, x + 24, 17, ["lines", "graph", "planet", "lines", "graph"][i])
        d.rectangle([x + 11, 20, x + 15, 22], fill=OUTLINE)
    for x in range(30, 220, 40):
        d.ellipse([x, 25, x + 6, 29], fill=random.choice([MAGENTA, CYAN, GREEN]), outline=OUTLINE)
    return img


def cafe_table():
    img, d = new(84, 60)
    # cadeiras
    for x in (2, 66):
        box(d, x, 18, x + 15, 50, FABRIC_D, light=FABRIC)
        d.line([x + 2, 48, x + 13, 48], fill=CYAN_D)
    # mesa
    box(d, 18, 16, 65, 42, METAL_L, light=METAL_H, dark=METAL)
    d.rectangle([38, 42, 45, 56], fill=METAL_D, outline=OUTLINE)
    d.ellipse([26, 22, 34, 28], fill=(240, 240, 250, 255), outline=OUTLINE)
    d.ellipse([50, 26, 57, 32], fill=MAGENTA, outline=OUTLINE)
    d.line([20, 40, 63, 40], fill=CYAN)
    return img


def pool_table():
    img, d = new(112, 72)
    box(d, 2, 2, 109, 61, WOOD, light=(130, 92, 70, 255), dark=(60, 40, 30, 255))
    d.rectangle([9, 9, 102, 54], fill=(20, 110, 70, 255), outline=OUTLINE)
    for x, y in [(9, 9), (55, 8), (102, 9), (9, 54), (55, 55), (102, 54)]:
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=OUTLINE)
    balls = [(30, 30, (255, 255, 255, 255)), (70, 28, (255, 200, 40, 255)), (76, 32, (220, 40, 40, 255)), (76, 24, (40, 80, 220, 255)), (82, 30, MAGENTA), (60, 40, (30, 30, 30, 255))]
    for x, y, c in balls:
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=c, outline=OUTLINE)
    d.line([12, 50, 36, 32], fill=(200, 170, 120, 255), width=2)
    box(d, 8, 61, 16, 70, (60, 40, 30, 255))
    box(d, 95, 61, 103, 70, (60, 40, 30, 255))
    return img


def arcade():
    img, d = new(48, 92)
    box(d, 4, 2, 43, 89, (40, 30, 70, 255), light=(80, 60, 130, 255), dark=(20, 14, 40, 255))
    glow(img, 9, 14, 38, 40, MAGENTA, 3, 60)
    d = ImageDraw.Draw(img)
    box(d, 8, 13, 39, 41, SCREEN_D)
    d.rectangle([12, 17, 35, 37], fill=(30, 10, 50, 255))
    for x, y, c in [(15, 30, CYAN), (22, 22, MAGENTA), (29, 32, GREEN), (19, 34, CYAN_H)]:
        d.rectangle([x, y, x + 2, y + 2], fill=c)
    d.rectangle([6, 4, 41, 10], fill=MAGENTA)
    d.text((10, 3), "PLAY", fill=(255, 255, 255, 255))
    box(d, 6, 46, 41, 58, METAL_D)
    d.ellipse([12, 49, 17, 54], fill=(220, 40, 40, 255))
    d.ellipse([24, 49, 28, 53], fill=CYAN)
    d.ellipse([31, 49, 35, 53], fill=GREEN)
    d.line([4, 86, 43, 86], fill=CYAN)
    return img


def holo_rug():
    img, d = new(120, 64)
    for r, a in [(0, 120), (4, 60)]:
        d.ellipse([4 + r, 4 + r, 115 - r, 59 - r], outline=CYAN[:3] + (a,), width=2)
    d.ellipse([30, 18, 89, 45], outline=CYAN[:3] + (150,), width=1)
    d.ellipse([52, 26, 67, 37], fill=CYAN[:3] + (70,), outline=CYAN[:3] + (170,))
    d.arc([36, 24, 83, 39], 190, 350, fill=CYAN_H[:3] + (170,))
    for a in range(0, 360, 45):
        x = 60 + math.cos(math.radians(a)) * 50
        y = 32 + math.sin(math.radians(a)) * 24
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=CYAN[:3] + (170,))
    return img


def bed():
    """Cama de solteiro vista de cima (cabeceira com neon em cima)."""
    img, d = new(64, 96)
    box(d, 2, 2, 61, 22, METAL, light=METAL_L, dark=METAL_D)  # cabeceira
    glow(img, 8, 8, 55, 10, CYAN, radius=3, strength=110)
    d = ImageDraw.Draw(img)
    d.line([8, 9, 55, 9], fill=CYAN_H)
    box(d, 4, 18, 59, 91, METAL_D, light=METAL)  # estrutura
    box(d, 7, 21, 56, 46, (226, 232, 246, 255), light=(255, 255, 255, 255), dark=(170, 180, 205, 255))  # lençol
    box(d, 12, 24, 51, 38, (240, 244, 255, 255), dark=(185, 195, 220, 255))  # travesseiro
    box(d, 6, 44, 57, 88, PURPLE, light=PURPLE_L, dark=(90, 50, 170, 255))  # cobertor
    d.line([6, 50, 57, 50], fill=PURPLE_L)
    for y in range(58, 86, 8):
        d.line([10, y, 53, y], fill=(120, 70, 220, 255))
    d.line([5, 92, 58, 92], fill=MAGENTA)
    return img


def nightstand():
    img, d = new(32, 40)
    box(d, 2, 10, 29, 37, WOOD, light=(128, 92, 72, 255), dark=(60, 40, 32, 255))
    d.line([6, 24, 25, 24], fill=OUTLINE)
    d.rectangle([14, 17, 17, 19], fill=CYAN)
    box(d, 10, 1, 21, 10, METAL, light=METAL_L)  # luminária
    glow(img, 11, 2, 20, 6, CYAN, radius=3, strength=120)
    return img


WHITE = (226, 232, 246, 255)
WHITE_L = (250, 252, 255, 255)
WHITE_D = (160, 172, 198, 255)
WATER = (90, 190, 240, 255)


def toilet():
    """Vaso sanitário visto de cima (caixa encostada na parede)."""
    img, d = new(32, 44)
    box(d, 5, 1, 26, 14, WHITE, light=WHITE_L, dark=WHITE_D)  # caixa
    d.rectangle([13, 4, 18, 6], fill=METAL_L)
    d.ellipse([4, 12, 27, 41], fill=OUTLINE)
    d.ellipse([5, 13, 26, 40], fill=WHITE)
    d.ellipse([9, 18, 22, 35], fill=WHITE_D)
    d.ellipse([11, 21, 20, 32], fill=WATER)
    d.arc([5, 13, 26, 40], 200, 330, fill=WHITE_L)
    return img


def sink():
    """Pia com espelho acima (encostada na parede)."""
    img, d = new(36, 52)
    box(d, 4, 0, 31, 20, METAL_D, light=METAL)  # espelho
    d.rectangle([7, 3, 28, 17], fill=(120, 170, 210, 255))
    d.line([9, 15, 18, 5], fill=WHITE_L)
    glow(img, 6, 21, 29, 21, CYAN, 2, 70)
    d = ImageDraw.Draw(img)
    box(d, 2, 24, 33, 49, WHITE, light=WHITE_L, dark=WHITE_D)  # bancada
    d.ellipse([8, 28, 27, 42], fill=OUTLINE)
    d.ellipse([9, 29, 26, 41], fill=WHITE_D)
    d.rectangle([16, 24, 19, 31], fill=METAL_H)  # torneira
    d.line([3, 50, 32, 50], fill=CYAN)
    return img


def shower():
    """Box de chuveiro: piso com ralo e vidro azulado."""
    img, d = new(56, 72)
    box(d, 1, 1, 54, 70, METAL_D, light=METAL)
    for y in range(6, 66, 8):
        for x in range(6, 50, 8):
            d.rectangle([x, y, x + 6, y + 6], fill=(70, 110, 140, 255))
    d.ellipse([24, 30, 31, 37], fill=OUTLINE)
    d.ellipse([25, 31, 30, 36], fill=METAL_H)
    box(d, 20, 3, 35, 10, METAL_L, light=METAL_H)  # chuveiro
    for i in range(6):
        d.point((22 + i * 2, 12 + (i % 2) * 2), fill=WATER)
    glass = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    gd.rectangle([2, 40, 53, 69], fill=(140, 210, 255, 70))
    gd.line([2, 40, 53, 40], fill=(200, 240, 255, 200))
    gd.line([8, 46, 20, 60], fill=(230, 250, 255, 120))
    img.alpha_composite(glass)
    return img


def fridge():
    img, d = new(40, 84)
    box(d, 2, 2, 37, 81, WHITE_D, light=WHITE, dark=(120, 130, 160, 255))
    d.line([3, 30, 36, 30], fill=OUTLINE)
    d.rectangle([31, 10, 33, 24], fill=METAL)
    d.rectangle([31, 36, 33, 54], fill=METAL)
    box(d, 8, 40, 24, 52, SCREEN_D)  # painel
    d.line([10, 44, 20, 44], fill=CYAN)
    d.line([10, 48, 16, 48], fill=GREEN)
    glow(img, 8, 40, 24, 52, CYAN, 2, 50)
    return img


def stove():
    img, d = new(44, 52)
    box(d, 1, 1, 42, 50, METAL, light=METAL_H, dark=METAL_D)
    box(d, 4, 4, 39, 30, (20, 22, 30, 255))
    for cx, cy in [(13, 11), (30, 11), (13, 23), (30, 23)]:
        d.ellipse([cx - 6, cy - 5, cx + 6, cy + 5], outline=(255, 110, 60, 255))
        d.ellipse([cx - 3, cy - 2, cx + 3, cy + 2], outline=(255, 170, 90, 255))
    box(d, 6, 34, 37, 47, METAL_D)  # forno
    d.rectangle([9, 37, 34, 44], fill=(255, 120, 60, 90))
    for x in range(8, 38, 7):
        d.rectangle([x, 31, x + 2, 32], fill=CYAN)
    return img


def kitchen_counter():
    img, d = new(64, 52)
    box(d, 1, 14, 62, 50, WOOD, light=(128, 92, 72, 255), dark=(60, 40, 32, 255))
    box(d, 1, 6, 62, 18, (190, 196, 214, 255), light=WHITE_L, dark=WHITE_D)  # tampo
    d.line([32, 20, 32, 48], fill=OUTLINE)
    d.rectangle([26, 30, 29, 34], fill=METAL_H)
    d.rectangle([35, 30, 38, 34], fill=METAL_H)
    d.ellipse([6, 1, 18, 11], fill=(200, 80, 60, 255), outline=OUTLINE)  # fruteira
    d.ellipse([9, 2, 14, 7], fill=(250, 200, 60, 255))
    box(d, 40, 0, 56, 10, METAL_L, light=METAL_H)  # cafeteira
    d.rectangle([44, 3, 52, 6], fill=CYAN)
    return img


def dining_table():
    img, d = new(64, 60)
    for x0, y0 in [(4, 0), (44, 0), (4, 44), (44, 44)]:  # cadeiras
        box(d, x0, y0, x0 + 15, y0 + 14, FABRIC, light=FABRIC_L, dark=FABRIC_D)
    box(d, 2, 10, 61, 47, WOOD, light=(140, 100, 78, 255), dark=(60, 40, 32, 255))
    d.ellipse([12, 20, 24, 32], fill=WHITE, outline=OUTLINE)
    d.ellipse([39, 22, 51, 34], fill=WHITE, outline=OUTLINE)
    d.rectangle([29, 18, 33, 30], fill=(120, 200, 255, 160))
    return img


def wardrobe():
    img, d = new(56, 92)
    box(d, 2, 2, 53, 89, WOOD, light=(128, 92, 72, 255), dark=(60, 40, 32, 255))
    d.line([28, 4, 28, 86], fill=OUTLINE)
    for x in (23, 32):
        d.rectangle([x, 40, x + 1, 52], fill=METAL_H)
    d.line([5, 80, 50, 80], fill=MAGENTA)
    glow(img, 5, 80, 50, 80, MAGENTA, 2, 60)
    return img


def desk_triple():
    """Estação de trabalho completa: mesa larga com três monitores."""
    img, d = new(112, 64)
    box(d, 2, 34, 109, 48, METAL, light=METAL_H, dark=METAL_D)  # tampo
    d.line([4, 47, 107, 47], fill=CYAN)
    box(d, 6, 48, 13, 62, METAL_D)
    box(d, 98, 48, 105, 62, METAL_D)
    box(d, 40, 48, 71, 60, METAL_D, light=METAL)  # gaveteiro central
    d.line([44, 54, 67, 54], fill=OUTLINE)
    for i, (x0, kind) in enumerate([(8, "lines"), (40, "planet"), (72, "graph")]):
        y0 = 6 if i == 1 else 9
        glow(img, x0, y0, x0 + 30, y0 + 20, CYAN, 3, 55)
        d = ImageDraw.Draw(img)
        box(d, x0, y0, x0 + 31, y0 + 21, METAL_D)
        screen(d, x0 + 2, y0 + 2, x0 + 29, y0 + 19, kind)
        d.rectangle([x0 + 14, y0 + 22, x0 + 17, 35], fill=OUTLINE)
    box(d, 38, 37, 74, 42, METAL_D)  # teclado
    for k in range(40, 72, 3):
        d.point((k, 39), fill=CYAN_D)
    box(d, 80, 37, 86, 42, METAL_D)  # mouse
    box(d, 16, 36, 24, 43, (60, 64, 90, 255))  # caneca
    return img


def office_chair():
    img, d = new(32, 36)
    box(d, 6, 2, 25, 18, FABRIC, light=FABRIC_L, dark=FABRIC_D)  # encosto
    d.line([9, 16, 22, 16], fill=CYAN)
    box(d, 4, 17, 27, 25, FABRIC_L, light=(90, 96, 140, 255), dark=FABRIC_D)  # assento
    d.rectangle([14, 26, 17, 30], fill=METAL_D)
    for x in (5, 15, 25):
        d.rectangle([x, 31, x + 2, 33], fill=METAL)
    return img


def server_console():
    """Console do servidor: bancada com dois monitores e painel de controle."""
    img, d = new(96, 64)
    box(d, 2, 30, 93, 50, METAL, light=METAL_H, dark=METAL_D)
    d.line([4, 49, 91, 49], fill=PURPLE)
    box(d, 6, 50, 90, 62, METAL_D, light=METAL)  # base fechada
    for x in range(12, 86, 8):
        d.rectangle([x, 54, x + 4, 56], fill=(40, 200, 120, 255) if (x // 8) % 3 else MAGENTA)
    for x0, kind in [(14, "lines"), (52, "graph")]:
        glow(img, x0, 3, x0 + 29, 23, CYAN, 3, 55)
        d = ImageDraw.Draw(img)
        box(d, x0, 2, x0 + 30, 24, METAL_D)
        screen(d, x0 + 2, 4, x0 + 28, 22, kind)
        d.rectangle([x0 + 13, 25, x0 + 17, 31], fill=OUTLINE)
    # painel de controle (botões e chaves)
    box(d, 20, 33, 76, 44, SCREEN_D)
    for i, x in enumerate(range(24, 72, 6)):
        d.rectangle([x, 36, x + 3, 38], fill=[CYAN, GREEN, MAGENTA, CYAN_H][i % 4])
        d.line([x, 41, x + 3, 41], fill=CYAN_D)
    return img


def rack_tall():
    img, d = new(44, 92)
    box(d, 2, 2, 41, 89, METAL_D, light=METAL, dark=OUTLINE)
    for y in range(8, 84, 10):
        box(d, 6, y, 37, y + 7, (16, 22, 34, 255))
        for x in range(9, 22, 3):
            d.point((x, y + 3), fill=CYAN if (x + y) % 2 else GREEN)
        d.line([24, y + 3, 34, y + 3], fill=CYAN_D)
    glow(img, 4, 4, 39, 87, CYAN, 2, 40)
    return img


def banner():
    """Estandarte roxo da empresa (preso na parede)."""
    img, d = new(32, 60)
    d.rectangle([2, 2, 29, 4], fill=METAL_H)
    pts = [(4, 5), (27, 5), (27, 50), (16, 57), (4, 50)]
    d.polygon(pts, fill=(90, 40, 170, 255), outline=OUTLINE)
    d.line([6, 6, 6, 49], fill=(130, 70, 220, 255))
    # logo: hexágono com ponto
    cx, cy = 16, 24
    hexp = [(cx + 7 * math.cos(math.radians(a)), cy + 7 * math.sin(math.radians(a))) for a in range(30, 390, 60)]
    d.polygon(hexp, outline=PURPLE_L)
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=CYAN_H)
    glow(img, 10, 18, 22, 30, PURPLE, 3, 60)
    return img


def coffee_table():
    img, d = new(48, 24)
    box(d, 2, 4, 45, 15, METAL, light=METAL_H, dark=METAL_D)
    box(d, 8, 6, 39, 12, SCREEN_D)
    d.line([10, 9, 37, 9], fill=CYAN)
    d.rectangle([6, 16, 9, 22], fill=METAL_D)
    d.rectangle([38, 16, 41, 22], fill=METAL_D)
    return img


def dev_desk():
    """Mesa do Dev. Jr. (canto da sala): um monitor e um gráfico."""
    img, d = new(72, 56)
    box(d, 2, 28, 69, 42, METAL, light=METAL_H, dark=METAL_D)
    d.line([4, 41, 67, 41], fill=CYAN)
    box(d, 6, 42, 12, 54, METAL_D)
    box(d, 59, 42, 65, 54, METAL_D)
    for x0, kind in [(6, "lines"), (38, "graph")]:
        glow(img, x0, 4, x0 + 27, 22, CYAN, 3, 50)
        d = ImageDraw.Draw(img)
        box(d, x0, 3, x0 + 28, 23, METAL_D)
        screen(d, x0 + 2, 5, x0 + 26, 21, kind)
        d.rectangle([x0 + 12, 24, x0 + 16, 29], fill=OUTLINE)
    return img


def tv():
    return wall_screen("planet", 112, 60)


def main():
    os.makedirs(OUT, exist_ok=True)
    items = {
        "plant": plant(), "screen_triple": wall_screen("triple", 168, 56), "screen_dna": wall_screen("dna", 112, 52),
        "screen_graph": wall_screen("graph", 64, 44), "tv": tv(), "poster": poster(), "vending": vending(),
        "sofa": sofa(), "armchair": armchair(), "hologram": hologram(), "holo_globe": holo_globe(), "rack": rack(),
        "shelf": shelf(), "workstation": workstation(), "tube": tube(), "tube_big": tube(True), "lab_bench": lab_bench(),
        "crystals": crystals(), "counter": counter(), "cafe_table": cafe_table(), "pool_table": pool_table(),
        "arcade": arcade(), "holo_rug": holo_rug(), "bed": bed(), "nightstand": nightstand(),
        "toilet": toilet(), "sink": sink(), "shower": shower(), "fridge": fridge(), "stove": stove(),
        "kitchen_counter": kitchen_counter(), "dining_table": dining_table(), "wardrobe": wardrobe(),
        "desk_triple": desk_triple(), "office_chair": office_chair(), "server_console": server_console(),
        "rack_tall": rack_tall(), "banner": banner(), "coffee_table": coffee_table(), "dev_desk": dev_desk(),
    }
    for name, img in items.items():
        save(img, name)
    print("%d móveis gerados em %s" % (len(items), os.path.normpath(OUT)))


if __name__ == "__main__":
    sys.exit(main())
