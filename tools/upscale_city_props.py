#!/usr/bin/env python3
"""Gera versões em alta resolução (3x) do Centro de Tecnologia e dos objetos
da rua (poste, árvore, banco, floreira, ponto de ônibus...).

A arte original vem de um JPG pequeno (assets/source/cyber_exterior.jpg), e
ampliar isso com "vizinho mais próximo" deixava tudo borrado e quadriculado.
Aqui cada recorte é limpo (tira o ruído do JPG), ampliado 4x com uma rede de
super-resolução (EDSR, do OpenCV) e reduzido para 3x o tamanho do jogo.
O jogo desenha essas imagens em 1/3 do tamanho com filtro suave
(City._use_hd_props e Building.gd), então fica tudo nítido com a câmera em zoom 2.

Uso (na pasta do projeto):
  pip install opencv-contrib-python-headless
  baixe EDSR_x4.pb de github.com/Saafke/EDSR_Tensorflow (pasta models)
  python3 tools/upscale_city_props.py caminho/para/EDSR_x4.pb

Saída: assets/environment/cyber/tech_center.png (480x864, o prédio já sabe
desenhar em 1/3) e assets/environment/cyber/hd/<objeto>.png.
"""
import os
import sys

import cv2
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SOURCE = os.path.join(ROOT, "assets", "source", "cyber_exterior.jpg")
OUT = os.path.join(ROOT, "assets", "environment", "cyber")
DENSITY = 3
MARGIN = 4

# nome: (recorte no JPG [x, y, w, h], tamanho no jogo [w, h]) — os mesmos de
# tools/import_cyber_exterior.gd.
ITEMS = {
    "tech_center": ((1398, 222, 171, 286), (160, 288)),
    "bench": ((20, 249, 54, 46), (64, 32)),
    "planter": ((248, 320, 63, 43), (64, 32)),
    "lamp": ((488, 239, 25, 74), (32, 96)),
    "kiosk": ((364, 244, 37, 65), (32, 64)),
    "shelter": ((580, 240, 98, 74), (96, 96)),
    "bin": ((296, 247, 27, 48), (32, 32)),
    "tree": ((1300, 105, 58, 66), (64, 96)),
    "flowers": ((1360, 108, 56, 62), (64, 64)),
}


def upscale(sr, image):
    clean = cv2.fastNlMeansDenoisingColored(image, None, 4, 4, 5, 15)
    big = sr.upsample(clean)
    # realce leve de contorno (o EDSR deixa um pouco "macio")
    blur = cv2.GaussianBlur(big, (0, 0), 1.2)
    return cv2.addWeighted(big, 1.35, blur, -0.35, 0)


def backdrop_mask(rgb):
    """Fundo escuro ligado às bordas do recorte vira transparente."""
    b, g, r = cv2.split(rgb.astype(np.float32) / 255.0)
    dark = ((r <= 0.10) & (g <= 0.16) & (b <= 0.20)).astype(np.uint8)
    h, w = dark.shape
    flood = dark.copy() * 255
    mask = np.zeros((h + 2, w + 2), np.uint8)
    for x in range(w):
        for y in (0, h - 1):
            if flood[y, x] == 255:
                cv2.floodFill(flood, mask, (x, y), 128)
    for y in range(h):
        for x in (0, w - 1):
            if flood[y, x] == 255:
                cv2.floodFill(flood, mask, (x, y), 128)
    alpha = np.where(flood == 128, 0, 255).astype(np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    return cv2.GaussianBlur(alpha, (3, 3), 0)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sr = cv2.dnn_superres.DnnSuperResImpl_create()
    sr.readModel(sys.argv[1])
    sr.setModel("edsr", 4)
    source = cv2.imread(SOURCE)
    os.makedirs(os.path.join(OUT, "hd"), exist_ok=True)
    for name, ((x, y, w, h), (cw, ch)) in ITEMS.items():
        x0, y0 = max(0, x - MARGIN), max(0, y - MARGIN)
        x1, y1 = min(source.shape[1], x + w + MARGIN), min(source.shape[0], y + h + MARGIN)
        big = upscale(sr, source[y0:y1, x0:x1])
        ox, oy = (x - x0) * 4, (y - y0) * 4
        big = big[oy:oy + h * 4, ox:ox + w * 4]
        alpha = backdrop_mask(big)
        rgba = np.dstack([big, alpha])
        factor = min((cw - 2) / w, (ch - 2) / h) * DENSITY
        size = (round(w * factor), round(h * factor))
        small = cv2.resize(rgba, size, interpolation=cv2.INTER_AREA)
        canvas = np.zeros((ch * DENSITY, cw * DENSITY, 4), np.uint8)
        px = (cw * DENSITY - size[0]) // 2
        py = ch * DENSITY - size[1]
        canvas[py:py + size[1], px:px + size[0]] = small
        target = os.path.join(OUT, name + ".png") if name == "tech_center" else os.path.join(OUT, "hd", name + ".png")
        cv2.imwrite(target, canvas)
        print("ok", name, canvas.shape[1], "x", canvas.shape[0])


if __name__ == "__main__":
    main()
