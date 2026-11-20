#!/usr/bin/env python3
"""Gera os sons ambientes dos interiores (WAV mono, 22050 Hz, em loop).

Uso (na pasta do projeto):  python3 tools/gen_ambient_sounds.py
Só usa a biblioteca padrão do Python. Saída: assets/audio/ambient_*.wav

Cada som tem exatamente LOOP_SECONDS e é feito só de ondas que "fecham" no
fim do loop, então emenda sem estalo quando o jogo repete (InteriorBase.gd
liga o loop ao tocar).
  ambient_office.wav  zumbido de servidores e ventoinhas (escritório)
  ambient_lab.wav     zumbido grave + bolhas nos tubos (laboratório)
  ambient_cafe.wav    acordes suaves de sintetizador (área social)
  ambient_house.wav   fundo calmo, quase silêncio (casa)
"""
import math
import os
import random
import struct
import wave

RATE = 22050
LOOP_SECONDS = 8
N = RATE * LOOP_SECONDS
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def tone(freq_hz, t):
    # Frequência ajustada para dar um número inteiro de ciclos no loop.
    cycles = max(1, round(freq_hz * LOOP_SECONDS))
    return math.sin(2 * math.pi * cycles * t / LOOP_SECONDS)


def smooth_noise(seed, step):
    """Ruído suave e periódico (ventoinha): interpola pontos aleatórios."""
    rnd = random.Random(seed)
    points = [rnd.uniform(-1, 1) for _ in range(N // step)]
    out = []
    for i in range(N):
        a = points[(i // step) % len(points)]
        b = points[(i // step + 1) % len(points)]
        f = (i % step) / step
        f = f * f * (3 - 2 * f)
        out.append(a + (b - a) * f)
    return out


def office():
    fan = smooth_noise(1, 6)
    samples = []
    for i in range(N):
        t = i / RATE
        hum = 0.35 * tone(60, t) + 0.18 * tone(120, t) + 0.06 * tone(180, t)
        beat = 0.5 + 0.5 * tone(0.25, t)  # o zumbido "respira" devagar
        samples.append(0.22 * hum * (0.8 + 0.2 * beat) + 0.1 * fan[i])
    return samples


def lab():
    samples = [0.2 * (0.4 * tone(55, i / RATE) + 0.15 * tone(110, i / RATE)) for i in range(N)]
    rnd = random.Random(5)
    for _ in range(22):  # bolhas: um "plip" que sobe de tom
        start = rnd.randrange(0, N - 4000)
        base = rnd.uniform(500, 1100)
        for k in range(1800):
            t = k / RATE
            env = math.exp(-t * 28)
            samples[start + k] += 0.18 * env * math.sin(2 * math.pi * (base + 2200 * t) * t)
    return samples


def cafe():
    # Quatro acordes (2 s cada), com volume subindo e descendo em cada um.
    chords = [[220.0, 277.18, 329.63], [196.0, 246.94, 293.66], [174.61, 220.0, 261.63], [196.0, 246.94, 329.63]]
    samples = []
    for i in range(N):
        t = i / RATE
        idx = int(t // 2) % 4
        local = t % 2
        env = math.sin(math.pi * local / 2) ** 2
        value = 0.0
        for f in chords[idx]:
            value += math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t)
        samples.append(0.07 * env * value)
    return samples


def house():
    air = smooth_noise(9, 40)
    return [0.05 * air[i] + 0.04 * tone(110, i / RATE) * (0.5 + 0.5 * tone(0.125, i / RATE)) for i in range(N)]


def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, 0.8 / peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("ambient_office", office), ("ambient_lab", lab), ("ambient_cafe", cafe), ("ambient_house", house)]:
        save(name, fn())
    print("Sons ambientes gerados em", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
