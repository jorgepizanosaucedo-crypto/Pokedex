"""Blip de la vocecita de Karen: un pulso cuadrado cortito, uno por letra.

Uso: python tools/generate_voice.py  ->  assets/sounds/voice.wav
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds", "voice.wav")


def main():
    n = int(0.045 * SR)
    t = np.arange(n) / SR
    # Un glissando corto hacia abajo suena a voz de consola, no a pitido plano.
    freq = 760 - 180 * (t / t[-1])
    phase = np.cumsum(freq / SR) % 1.0
    wave_ = np.where(phase < 0.35, 1.0, -1.0)
    env = np.minimum(1, np.linspace(0, 1, n) * 12) * np.linspace(1, 0, n) ** 2
    sig = np.tanh(wave_ * env * 0.9) * 0.5

    path = os.path.abspath(OUT)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((sig * 32767).astype("<i2").tobytes())
    print(f"{path}  {os.path.getsize(path)} bytes  {n / SR * 1000:.0f} ms")


if __name__ == "__main__":
    main()
