"""Genera la música de ambiente de la Pokédex: temas chiptune originales.

Composiciones propias al estilo de las consolas portátiles de 8 bits (dos
canales de pulso, bajo triangular y ruido de percusión). No reproducen ninguna
melodía con derechos de autor.

Uso:
    python tools/generate_music.py

Escribe en assets/music/ un bucle por ambiente. Cada uno empalma sin costura:
el eco se aplica con envoltura circular, así la cola entra por el principio.
"""

import os
import shutil
import subprocess
import wave

import numpy as np

SR = 22050  # de sobra para ondas de 8 bits, y deja los archivos a la mitad
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "music")

# Acordes y sus fundamentales, en números MIDI.
CH = {
    "C": ([60, 64, 67], 48), "Am": ([57, 60, 64], 45), "F": ([53, 57, 60], 41),
    "G": ([55, 59, 62], 43), "Dm": ([50, 53, 57], 38), "Em": ([52, 55, 59], 40),
    "D": ([50, 54, 57], 38), "Bb": ([58, 62, 65], 46), "Gm": ([55, 58, 62], 43),
    "A": ([57, 61, 64], 45),
}


class Mood:
    """Un ambiente: su progresión, su melodía y cómo suena."""

    def __init__(self, name, bpm, prog, melody, duty=0.25, arp_duty=0.125,
                 snare=True, kick=True, hat=1.0, echo_fb=0.3, octave=False,
                 bass_pattern=(0, 0, 7, 0, 0, 0, 7, 12), arp_step=4, gain=1.0):
        self.name, self.bpm, self.prog, self.melody = name, bpm, prog, melody
        self.duty, self.arp_duty = duty, arp_duty
        self.snare, self.kick, self.hat = snare, kick, hat
        self.echo_fb, self.octave = echo_fb, octave
        self.bass_pattern, self.arp_step, self.gain = bass_pattern, arp_step, gain

    @property
    def beat(self):
        return 60.0 / self.bpm

    @property
    def eighth(self):
        return self.beat / 2

    @property
    def bar(self):
        return self.beat * 4

    @property
    def samples(self):
        return int(round(len(self.prog) * self.bar * SR))


# El tema del mapa: brillante y curioso, el que suena en la lista.
THEME = Mood(
    "theme", 112,
    ["C", "Am", "F", "G", "C", "Am", "Dm", "G"],
    [(79, 2), (76, 1), (79, 1), (84, 2), (83, 1), (79, 1),
     (81, 2), (76, 1), (81, 1), (84, 2), (83, 1), (81, 1),
     (81, 2), (77, 1), (81, 1), (84, 1), (86, 1), (84, 1), (81, 1),
     (83, 2), (79, 1), (83, 1), (86, 2), (83, 1), (79, 1),
     (88, 2), (86, 1), (84, 1), (83, 2), (79, 1), (76, 1),
     (84, 2), (83, 1), (81, 1), (79, 2), (76, 1), (81, 1),
     (86, 2), (84, 1), (81, 1), (77, 2), (81, 1), (84, 1),
     (83, 2), (86, 2), (79, 4)],
)

# Fuego y lucha: rápido, menor, con la percusión al frente.
FIRE = Mood(
    "fire", 134,
    ["Am", "F", "G", "Am"],
    [(69, 1), (72, 1), (76, 2), (72, 1), (69, 1), (67, 2),
     (65, 1), (69, 1), (72, 2), (69, 1), (65, 1), (64, 2),
     (67, 1), (71, 1), (74, 2), (71, 1), (67, 1), (69, 2),
     (69, 2), (76, 2), (74, 1), (72, 1), (69, 2)],
    duty=0.5, hat=1.2, echo_fb=0.22, gain=1.05,
)

# Agua y hielo: lento, notas largas y mucho eco.
WATER = Mood(
    "water", 92,
    ["C", "Am", "Dm", "G"],
    [(72, 4), (76, 4), (74, 4), (72, 4), (69, 4), (77, 4), (76, 2), (74, 2), (71, 4)],
    duty=0.125, arp_duty=0.25, snare=False, kick=False, hat=0.45,
    echo_fb=0.42, bass_pattern=(0, None, 7, None, 0, None, 12, None), gain=0.95,
)

# Planta y bicho: pastoral y tranquilo.
GRASS = Mood(
    "grass", 104,
    ["F", "C", "Dm", "G"],
    [(77, 2), (81, 2), (84, 2), (81, 2), (79, 2), (76, 2), (79, 4),
     (81, 2), (77, 2), (81, 2), (84, 2), (83, 2), (79, 2), (74, 4)],
    duty=0.25, snare=False, hat=0.6, echo_fb=0.3,
)

# Eléctrico y volador: semicorcheas nerviosas y brillantes.
ELECTRIC = Mood(
    "electric", 142,
    ["Em", "C", "G", "D"],
    [(76, 1), (79, 1), (83, 1), (79, 1), (76, 1), (79, 1), (83, 1), (88, 1),
     (84, 1), (81, 1), (84, 1), (88, 1), (84, 1), (81, 1), (79, 1), (76, 1),
     (79, 1), (83, 1), (86, 1), (83, 1), (79, 1), (83, 1), (86, 1), (91, 1),
     (86, 1), (83, 1), (81, 1), (78, 1), (74, 2), (81, 2)],
    duty=0.125, hat=1.1, echo_fb=0.26, arp_step=2,
)

# Siniestro, fantasma y veneno: grave, espaciado e inquietante.
DARK = Mood(
    "dark", 86,
    ["Dm", "Bb", "Gm", "A"],
    [(74, 3), (77, 1), (74, 4), (70, 3), (74, 1), (70, 4),
     (67, 3), (70, 1), (67, 4), (69, 4), (68, 4)],
    duty=0.5, arp_duty=0.5, snare=False, kick=True, hat=0.3,
    echo_fb=0.45, bass_pattern=(0, None, None, None, 0, None, 7, None), gain=0.9,
)

# Legendarios y singulares: solemne, con la melodía doblada en octavas.
LEGENDARY = Mood(
    "legendary", 96,
    ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"],
    [(74, 4), (81, 4), (82, 4), (81, 2), (79, 2), (77, 4), (84, 4),
     (84, 2), (83, 2), (79, 4), (86, 4), (84, 2), (81, 2), (82, 4), (79, 4),
     (79, 2), (82, 2), (86, 4), (85, 4), (81, 4)],
    duty=0.5, arp_duty=0.25, hat=0.7, echo_fb=0.38, octave=True,
    bass_pattern=(0, 0, None, None, 7, None, 12, None), gain=1.1,
)

MOODS = [THEME, FIRE, WATER, GRASS, ELECTRIC, DARK, LEGENDARY]


def midi_hz(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def envelope(n, attack=0.004, decay=0.06, sustain=0.72, release=0.05):
    """Envolvente corta y marcada, como la de un generador de 8 bits."""
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = min(max(1, int(release * SR)), max(1, n // 3))
    body = max(0, n - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, sustain, d, endpoint=False),
        np.full(body, sustain),
        np.linspace(sustain, 0, r),
    ])
    return np.resize(env, n)


def pulse(freq, n, duty=0.5, vibrato=0.0):
    """Onda cuadrada con ciclo de trabajo variable: los canales de pulso."""
    t = np.arange(n) / SR
    f = freq * (1 + vibrato * np.sin(2 * np.pi * 5.4 * t)) if vibrato else freq
    phase = np.cumsum(np.full(n, f) / SR) % 1.0 if np.isscalar(f) else np.cumsum(f / SR) % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def triangle(freq, n):
    phase = (np.arange(n) / SR * freq) % 1.0
    return 4 * np.abs(phase - 0.5) - 1


def add(track, start, data):
    """Suma con envoltura: lo que se sale por el final entra por el principio."""
    np.add.at(track, (np.arange(len(data)) + start) % len(track), data)


def smooth(sig, width):
    """Paso bajo suave para quitarle filo al cuadrado, sin perder el carácter."""
    kernel = np.hanning(width)
    return np.convolve(sig, kernel / kernel.sum(), mode="same")


def build_melody(m):
    track = np.zeros(m.samples)
    pos = 0
    for note, length in m.melody:
        n = int(round(length * m.eighth * SR))
        if note is not None:
            voice = (
                pulse(midi_hz(note), n, duty=m.duty, vibrato=0.004)
                + 0.45 * pulse(midi_hz(note) * 1.001, n, duty=0.5)
            )
            if m.octave:  # las octavas graves dan el peso de los legendarios
                voice += 0.6 * pulse(midi_hz(note - 12), n, duty=0.5)
            add(track, pos, voice * envelope(n) * 0.5)
        pos += n
    return smooth(track, 12)


def build_harmony(m):
    """Arpegios en el segundo canal de pulso."""
    track = np.zeros(m.samples)
    unit = m.eighth / 2
    n = int(round(unit * SR))
    pattern = [0, 1, 2, 1]
    for bar, name in enumerate(m.prog):
        chord = CH[name][0]
        for step in range(0, 16, max(1, m.arp_step // 2)):
            note = chord[pattern[step % 4]] + (12 if step >= 8 else 0)
            start = int(round((bar * m.bar + step * unit) * SR))
            voice = pulse(midi_hz(note), n, duty=m.arp_duty)
            add(track, start, voice * envelope(n, decay=0.03, sustain=0.5) * 0.5)
    return smooth(track, 20)


def build_bass(m):
    """Bajo triangular: la fundamental del acorde, con quintas y octavas."""
    track = np.zeros(m.samples)
    n = int(round(m.eighth * SR))
    for bar, name in enumerate(m.prog):
        root = CH[name][1]
        for step, semitones in enumerate(m.bass_pattern):
            if semitones is None:
                continue
            start = int(round((bar * m.bar + step * m.eighth) * SR))
            voice = triangle(midi_hz(root + semitones), n)
            add(track, start, voice * envelope(n, decay=0.05, sustain=0.6) * 0.75)
    return smooth(track, 6)


def build_percussion(m):
    rng = np.random.default_rng(1996)
    track = np.zeros(m.samples)
    for bar in range(len(m.prog)):
        for step in range(8):
            start = int(round((bar * m.bar + step * m.eighth) * SR))
            if m.hat:
                n = int(0.028 * SR)
                hat = rng.uniform(-1, 1, n) * np.linspace(1, 0, n) ** 3
                add(track, start, hat * (0.3 if step % 2 == 0 else 0.16) * m.hat)
            if m.snare and step in (2, 6):
                n = int(0.085 * SR)
                snare = rng.uniform(-1, 1, n) * np.linspace(1, 0, n) ** 2
                add(track, start, smooth(snare, 6) * 0.55)
        if m.kick:
            for step in (0, 4):
                start = int(round((bar * m.bar + step * m.eighth) * SR))
                n = int(0.11 * SR)
                t = np.arange(n) / SR
                kick = np.sin(2 * np.pi * (72 - 36 * t / t[-1]) * t) * np.linspace(1, 0, n) ** 2
                add(track, start, kick * 0.7)
    return track


def echo(sig, delay_seconds, feedback, taps=3):
    """Eco con envoltura circular: la cola entra por el principio del bucle."""
    out = sig.copy()
    d = int(round(delay_seconds * SR))
    for k in range(1, taps + 1):
        out += (feedback ** k) * np.roll(sig, d * k)
    return out


def render(m):
    melody = echo(build_melody(m), m.eighth * 1.5, m.echo_fb)
    harmony = build_harmony(m)
    bass = build_bass(m)
    perc = build_percussion(m)

    # Melodía algo a la derecha, arpegios a la izquierda, bajo al centro.
    left = 0.28 * melody * 0.85 + 0.15 * harmony + 0.26 * bass + 0.07 * perc
    right = 0.28 * melody + 0.15 * harmony * 0.85 + 0.26 * bass + 0.07 * perc

    stereo = np.stack([left, right], axis=1) * m.gain
    stereo = np.tanh(stereo * 1.15)
    stereo *= 0.82 / np.max(np.abs(stereo))

    path = os.path.abspath(os.path.join(OUT_DIR, f"{m.name}.wav"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((stereo * 32767).astype("<i2").tobytes())

    # La app carga MP3: pesa un 90 % menos que el WAV, así que en web el
    # cambio de ambiente no le quita ancho de banda a las imágenes.
    mp3 = path[:-4] + ".mp3"
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-codec:a", "libmp3lame", "-b:a", "96k", mp3],
        check=True,
    )
    os.remove(path)

    size = os.path.getsize(mp3) / 1024
    print(f"  {m.name:10s} {m.samples / SR:5.1f}s  {m.bpm:3d} BPM  {len(m.prog)} compases  {size:6.0f} KB")


def main():
    if shutil.which("ffmpeg") is None:
        raise SystemExit("Hace falta ffmpeg para convertir los temas a MP3.")
    print(f"Sintetizando a {SR} Hz, estéreo:")
    for mood in MOODS:
        render(mood)
    total = sum(os.path.getsize(os.path.join(OUT_DIR, f"{m.name}.mp3")) for m in MOODS)
    print(f"  total: {total / 1024 / 1024:.1f} MB en {os.path.abspath(OUT_DIR)}")


if __name__ == "__main__":
    main()
