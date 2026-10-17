"""Efectos del combate contra Karen: golpes, subidas de nivel, desmayo...

Sonidos de 8 bits hechos a mano con ondas de pulso y ruido, como el resto de
efectos de la app. Ninguno copia un sonido de los juegos.

Uso: python tools/generate_battle_sfx.py  ->  assets/sounds/*.wav
"""
import os
import wave

import numpy as np

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(7)


def t_of(seconds):
    return np.arange(int(seconds * SR)) / SR


def pulse(freq, duty=0.5):
    """Onda de pulso con frecuencia variable (un array por muestra)."""
    phase = np.cumsum(freq / SR) % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def noise(n, hold=1):
    """Ruido de consola: cada valor se repite `hold` muestras (más grave)."""
    raw = rng.uniform(-1, 1, n // hold + 1)
    return np.repeat(raw, hold)[:n]


def env(n, attack=0.005, power=2.0):
    a = max(1, int(attack * SR))
    e = np.linspace(1, 0, n) ** power
    e[:a] *= np.linspace(0, 1, a)
    return e


def hit():
    t = t_of(0.18)
    n = len(t)
    thump = pulse(150 - 90 * t / t[-1], 0.5) * env(n, power=3)
    crack = noise(n, 2) * env(n, power=6)
    return 0.55 * thump + 0.5 * crack


def hit_super():
    t = t_of(0.34)
    n = len(t)
    thump = pulse(220 * (1 - 0.75 * t / t[-1]), 0.5) * env(n, power=2.5)
    crack = noise(n, 3) * env(n, power=3)
    ring = pulse(np.full(n, 880.0), 0.25) * env(n, power=8) * 0.3
    return 0.55 * thump + 0.55 * crack + ring


def hit_weak():
    t = t_of(0.12)
    n = len(t)
    return 0.45 * pulse(110 - 40 * t / t[-1], 0.5) * env(n, power=3) + 0.2 * noise(n, 6) * env(n, power=5)


def whoosh():
    t = t_of(0.3)
    n = len(t)
    # Ruido que sube y baja de "grosor": el hold cambia la altura aparente.
    out = np.zeros(n)
    for i, hold in enumerate((8, 6, 4, 3, 2, 3, 4)):
        seg = slice(i * n // 7, (i + 1) * n // 7)
        out[seg] = noise(n, hold)[seg]
    shape = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return 0.4 * out * shape


def arpeggio(notes, step, duty=0.25, tail=0.08):
    parts = []
    for midi in notes:
        f = 440 * 2 ** ((midi - 69) / 12)
        n = int(step * SR)
        parts.append(pulse(np.full(n, f), duty) * env(n, attack=0.002, power=1.2))
    parts.append(np.zeros(int(tail * SR)))
    return 0.35 * np.concatenate(parts)


def buff():
    return arpeggio([64, 68, 71, 76, 80], 0.055)


def debuff():
    return arpeggio([76, 71, 67, 62, 58], 0.065, duty=0.5)


def heal():
    return arpeggio([72, 76, 79, 84, 79, 84, 88], 0.045, duty=0.125)


def faint():
    t = t_of(0.75)
    n = len(t)
    freq = 620 * (1 - 0.8 * (t / t[-1]) ** 0.7)
    wobble = 1 + 0.04 * np.sin(2 * np.pi * 11 * t)
    return 0.4 * pulse(freq * wobble, 0.5) * env(n, attack=0.01, power=1.3)


def miss():
    t = t_of(0.2)
    n = len(t)
    return 0.3 * noise(n, 1) * np.sin(np.linspace(0, np.pi, n)) ** 2


def write(name, sig):
    sig = np.tanh(sig * 1.2) * 0.8
    path = os.path.abspath(os.path.join(OUT_DIR, f"{name}.wav"))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((sig * 32767).astype("<i2").tobytes())
    print(f"{name:10s} {os.path.getsize(path):6d} bytes  {len(sig) / SR * 1000:.0f} ms")


def main():
    for name, fn in [
        ("hit", hit),
        ("hitSuper", hit_super),
        ("hitWeak", hit_weak),
        ("whoosh", whoosh),
        ("buff", buff),
        ("debuff", debuff),
        ("heal", heal),
        ("faint", faint),
        ("miss", miss),
    ]:
        write(name, fn())


if __name__ == "__main__":
    main()
