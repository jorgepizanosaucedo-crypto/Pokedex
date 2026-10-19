"""Efectos de la interfaz: tarjetas, filtros, favoritos, pestañas, el dado,
las formas, el login... y un sonido por cada uno de los 18 tipos, que suena
al abrir la ficha de un Pokémon.

Mismo estilo de 8 bits que el resto (ondas de pulso y ruido), hechos a mano.
Ninguno copia un sonido de los juegos.

Uso: python tools/generate_ui_sfx.py  ->  assets/sounds/*.wav
"""
import os
import wave

import numpy as np

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(11)


# ------------------------------------------------------------- utilidades

def t_of(seconds):
    return np.arange(int(seconds * SR)) / SR


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def pulse(freq, duty=0.5):
    """Onda de pulso; `freq` puede ser un número o un array por muestra."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), np.shape(freq) or (1,))
    phase = np.cumsum(freq / SR) % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def tri(freq):
    """Triangular de consola: más suave que el pulso."""
    phase = np.cumsum(np.asarray(freq, dtype=float) / SR) % 1.0
    return 4 * np.abs(phase - 0.5) - 1


def sine(freq):
    phase = np.cumsum(np.asarray(freq, dtype=float) / SR)
    return np.sin(2 * np.pi * phase)


def noise(n, hold=1):
    raw = rng.uniform(-1, 1, n // hold + 1)
    return np.repeat(raw, hold)[:n]


def env(n, attack=0.004, power=2.0):
    a = max(1, min(n, int(attack * SR)))
    e = np.linspace(1, 0, n) ** power
    e[:a] *= np.linspace(0, 1, a)
    return e


def glide(f0, f1, seconds, curve=1.0):
    t = t_of(seconds)
    x = (t / max(t[-1], 1e-9)) ** curve
    return f0 + (f1 - f0) * x


def note(midi, seconds, duty=0.25, power=1.4, attack=0.003, wave="pulse"):
    n = int(seconds * SR)
    f = np.full(n, hz(midi))
    osc = {"pulse": lambda: pulse(f, duty), "tri": lambda: tri(f), "sine": lambda: sine(f)}[wave]()
    return osc * env(n, attack, power)


def seq(*parts):
    return np.concatenate(parts)


def silence(seconds):
    return np.zeros(int(seconds * SR))


def mix(*layers):
    n = max(len(x) for x in layers)
    out = np.zeros(n)
    for x in layers:
        out[: len(x)] += x
    return out


def at(seconds, sig, total):
    """Coloca `sig` empezando en `seconds` dentro de un silencio de `total`."""
    out = np.zeros(int(total * SR))
    start = int(seconds * SR)
    end = min(len(out), start + len(sig))
    out[start:end] += sig[: end - start]
    return out


# ------------------------------------------------------------- interfaz

def card():
    """Tocar la tarjeta de un Pokémon: un "pop" que sube."""
    f = glide(520, 1250, 0.07, 0.6)
    pop = pulse(f, 0.25) * env(len(f), power=1.6)
    tail = note(91, 0.06, duty=0.125, power=2.5) * 0.35
    return 0.42 * seq(pop, tail)


def chip():
    """Elegir un chip (tipo, filtro, opción)."""
    return 0.32 * seq(note(84, 0.03, 0.125, 1.2), note(91, 0.045, 0.125, 2.0))


def chip_off():
    """Quitar un chip."""
    return 0.3 * seq(note(88, 0.03, 0.125, 1.2), note(81, 0.05, 0.125, 2.0))


def sheet_up():
    """Abrir una hoja desde abajo (filtros, perfil, movimientos)."""
    f = glide(260, 760, 0.16, 0.8)
    body = pulse(f, 0.5) * np.sin(np.linspace(0, np.pi, len(f))) ** 1.2
    air = noise(len(f), 2) * np.sin(np.linspace(0, np.pi, len(f))) ** 2 * 0.25
    return 0.22 * (body + air)


def back():
    """Volver o cerrar: dos notas que bajan."""
    return 0.3 * seq(note(81, 0.045, 0.25, 1.5), note(76, 0.07, 0.25, 2.2))


def fav_on():
    """Corazón: entra al equipo."""
    run = seq(note(76, 0.05, 0.25), note(80, 0.05, 0.25), note(83, 0.05, 0.25), note(88, 0.12, 0.25, 2.0))
    sparkle = at(0.17, seq(note(100, 0.025, 0.125, 2.0), silence(0.02), note(103, 0.04, 0.125, 2.5)), 0.33)
    return 0.34 * mix(run, sparkle * 0.6)


def fav_off():
    """Sale del equipo."""
    return 0.3 * seq(note(83, 0.06, 0.5, 1.4), note(76, 0.1, 0.5, 2.2))


def tab():
    """Cambiar de pestaña."""
    click = noise(int(0.008 * SR), 1) * 0.5
    return 0.32 * seq(click, note(86, 0.04, 0.25, 2.2))


def dice():
    """El dado del botón "Al azar": rebota y suena una campanita."""
    total = 0.55
    out = np.zeros(int(total * SR))
    times = [0.0, 0.07, 0.13, 0.18, 0.22, 0.25]
    for i, t0 in enumerate(times):
        n = int(0.022 * SR)
        clack = noise(n, 2) * env(n, power=4) * (1 - i * 0.1)
        thud = pulse(np.full(n, 300 + 90 * rng.integers(0, 5)), 0.5) * env(n, power=3) * 0.4
        out += at(t0, clack + thud, total)
    ding = seq(note(96, 0.05, 0.125, 1.2), note(100, 0.16, 0.125, 2.0))
    out += at(0.31, ding * 0.8, total)
    return 0.38 * out


def toggle():
    """Interruptores (música, efectos, consejos, animado)."""
    return 0.3 * seq(note(79, 0.035, 0.5, 1.5), note(86, 0.05, 0.5, 2.0))


def morph():
    """Cambiar de forma (regional, Origen...): un brillo que sube."""
    f = glide(400, 1600, 0.45, 1.3) * (1 + 0.03 * np.sin(2 * np.pi * 18 * t_of(0.45)))
    body = pulse(f, 0.125) * np.sin(np.linspace(0, np.pi, len(f))) ** 0.8
    air = noise(len(f), 3) * np.linspace(0, 1, len(f)) ** 2 * env(len(f), 0.001, 0.5) * 0.3
    tail = seq(note(96, 0.04, 0.125), note(100, 0.04, 0.125), note(103, 0.12, 0.125, 2.0))
    return 0.3 * seq(body + air, tail)


def mega():
    """Megaevolución, gigamax, regresión primigenia: algo grande."""
    swell_t = t_of(0.55)
    rise = pulse(glide(110, 440, 0.55, 1.6), 0.5) * np.linspace(0.2, 1, len(swell_t)) ** 2
    rumble = noise(len(swell_t), 6) * np.linspace(0, 1, len(swell_t)) ** 3 * 0.6
    burst_n = int(0.12 * SR)
    burst = noise(burst_n, 1) * env(burst_n, power=2)
    chord = mix(note(60, 0.45, 0.5, 1.6), note(67, 0.45, 0.25, 1.6), note(72, 0.45, 0.125, 1.6)) * 0.6
    return 0.32 * seq(rise + rumble, mix(burst, chord))


def success():
    """Cuenta creada o sesión iniciada."""
    return 0.32 * seq(
        note(72, 0.07, 0.25), note(76, 0.07, 0.25), note(79, 0.07, 0.25), note(84, 0.24, 0.25, 1.6)
    )


def error():
    """Algo salió mal en el formulario."""
    return 0.3 * seq(note(52, 0.11, 0.5, 0.8), silence(0.03), note(48, 0.16, 0.5, 1.2))


def battle_start():
    """Entrar al combate contra Karen."""
    run = [72, 71, 72, 71, 72, 74, 76, 79]
    parts = [note(m, 0.045, 0.5, 1.0) for m in run]
    hit = mix(note(84, 0.28, 0.25, 1.4), note(72, 0.28, 0.5, 1.4) * 0.6)
    return 0.3 * seq(*parts, hit)


# ------------------------------------------------- un sonido por tipo

def t_normal():
    return 0.34 * seq(note(76, 0.06, 0.5), note(81, 0.06, 0.5), note(88, 0.14, 0.25, 2.0))


def t_fire():
    total = 0.5
    f = glide(260, 980, 0.36, 0.7) * (1 + 0.06 * np.sin(2 * np.pi * 30 * t_of(0.36)))
    flame = pulse(f, 0.5) * np.sin(np.linspace(0, np.pi, len(f))) ** 0.7
    out = at(0, flame * 0.55, total)
    for t0 in np.sort(rng.uniform(0, 0.42, 9)):  # chisporroteo
        n = int(0.012 * SR)
        out += at(t0, noise(n, 1) * env(n, power=3) * 0.7, total)
    return 0.4 * out


def t_water():
    total = 0.5
    out = np.zeros(int(total * SR))
    for t0, f0 in [(0.0, 420), (0.09, 620), (0.17, 520), (0.27, 820)]:
        f = glide(f0, f0 * 2.1, 0.07, 0.5)
        out += at(t0, tri(f) * env(len(f), power=1.5), total)
    return 0.45 * out


def t_grass():
    rustle_n = int(0.42 * SR)
    rustle = noise(rustle_n, 3) * np.sin(np.linspace(0, np.pi, rustle_n)) ** 2 * 0.35
    chime = seq(silence(0.08), note(79, 0.08, 0.125), note(83, 0.08, 0.125), note(86, 0.2, 0.125, 2.0))
    return 0.38 * mix(rustle, chime)


def t_electric():
    n = int(0.16 * SR)
    jitter = 1400 + 500 * noise(n, 40)
    zap = pulse(jitter, 0.5) * env(n, power=1.2) * 0.5
    arp = seq(*[note(m, 0.032, 0.25, 1.0) for m in [79, 86, 91, 79, 86, 91, 98]])
    return 0.34 * seq(zap, arp)


def t_ice():
    total = 0.55
    out = np.zeros(int(total * SR))
    for t0, m in [(0.0, 100), (0.06, 95), (0.12, 104), (0.2, 99), (0.28, 107)]:
        out += at(t0, note(m, 0.18, 0.125, 3.0), total)
    shimmer = noise(len(out), 1) * np.linspace(1, 0, len(out)) ** 3 * 0.12
    return 0.3 * (out + shimmer)


def t_fighting():
    def punch(f0):
        n = int(0.11 * SR)
        thump = pulse(glide(f0, f0 * 0.45, 0.11), 0.5) * env(n, power=3)
        crack = noise(n, 2) * env(n, power=6)
        return thump * 0.6 + crack * 0.55

    return 0.48 * seq(punch(170), silence(0.03), punch(220))


def t_poison():
    total = 0.55
    out = np.zeros(int(total * SR))
    for i, (t0, f0) in enumerate([(0.0, 330), (0.1, 280), (0.19, 300), (0.29, 220)]):
        f = glide(f0, f0 * 0.7, 0.09) * (1 + 0.08 * np.sin(2 * np.pi * 25 * t_of(0.09)))
        out += at(t0, pulse(f, 0.5) * env(len(f), power=1.2), total)
    return 0.32 * out


def t_ground():
    n = int(0.55 * SR)
    shape = np.sin(np.linspace(0, np.pi, n)) ** 0.8
    rumble = noise(n, 14) * shape * 0.8
    low = pulse(np.full(n, 62.0), 0.5) * shape * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t_of(0.55)))
    return 0.42 * (rumble + low * 0.6)


def t_flying():
    n = int(0.5 * SR)
    wind = np.zeros(n)
    for i, hold in enumerate((9, 7, 5, 4, 3, 4, 6)):
        seg = slice(i * n // 7, (i + 1) * n // 7)
        wind[seg] = noise(n, hold)[seg]
    shape = np.sin(np.linspace(0, np.pi, n)) ** 1.4
    flap = pulse(glide(420, 1100, 0.5, 1.2), 0.125) * shape * 0.25
    return 0.4 * (wind * shape * 0.7 + flap)


def t_psychic():
    t = t_of(0.55)
    f = glide(480, 820, 0.55, 0.8) * (1 + 0.07 * np.sin(2 * np.pi * 7 * t))
    body = pulse(f, 0.25) * np.sin(np.linspace(0, np.pi, len(t))) ** 0.6
    echo = np.concatenate([np.zeros(int(0.09 * SR)), body])[: len(body)] * 0.4
    return 0.24 * (body + echo)


def t_bug():
    t = t_of(0.45)
    buzz = pulse(np.full(len(t), 190.0), 0.5) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t)))
    shape = env(len(t), attack=0.03, power=1.0)
    trill = seq(*[note(m, 0.03, 0.125, 1.0) for m in [91, 93, 91, 93, 91, 93]])
    return 0.3 * mix(buzz * shape * 0.7, at(0.2, trill * 0.6, 0.45))


def t_rock():
    def clack(f0):
        n = int(0.07 * SR)
        return noise(n, 3) * env(n, power=5) * 0.7 + pulse(np.full(n, f0), 0.5) * env(n, power=4) * 0.5

    return 0.48 * seq(clack(160), silence(0.05), clack(120), silence(0.04), clack(200))


def t_ghost():
    t = t_of(0.6)
    f = glide(880, 300, 0.6, 0.9) * (1 + 0.05 * np.sin(2 * np.pi * 6 * t))
    shape = np.minimum(1, t / 0.12) * np.linspace(1, 0, len(t)) ** 1.2
    return 0.3 * (pulse(f, 0.5) * shape + tri(f * 1.5) * shape * 0.3)


def t_dragon():
    t = t_of(0.4)
    growl = pulse(glide(120, 80, 0.4), 0.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t))
    grit = noise(len(t), 5) * 0.35
    shape = env(len(t), attack=0.02, power=0.9)
    power_chord = mix(note(57, 0.22, 0.5, 1.5), note(64, 0.22, 0.25, 1.5), note(69, 0.22, 0.125, 1.5))
    return 0.36 * seq((growl + grit) * shape, power_chord * 0.8)


def t_dark():
    parts = [note(m, 0.12, 0.5, 1.0) for m in [57, 60, 64]]
    low = note(45, 0.36, 0.5, 1.4) * 0.5
    return 0.3 * mix(seq(*parts), low, at(0.36, note(56, 0.2, 0.5, 2.0), 0.6))


def t_steel():
    n = int(0.6 * SR)
    base = 980.0
    ping = sum(
        sine(np.full(n, base * r)) * a * np.linspace(1, 0, n) ** p
        for r, a, p in [(1.0, 1.0, 2.0), (2.76, 0.55, 3.0), (5.4, 0.3, 5.0), (8.9, 0.15, 7.0)]
    )
    click = np.zeros(n)
    click[: int(0.006 * SR)] = noise(int(0.006 * SR), 1)
    return 0.32 * (ping + click * 0.6)


def t_fairy():
    run = seq(*[note(m, 0.04, 0.125, 1.2) for m in [84, 88, 91, 96, 100]], note(103, 0.16, 0.125, 2.2))
    twinkle = at(0.08, seq(note(108, 0.02, 0.125), silence(0.05), note(105, 0.02, 0.125)), 0.4)
    return 0.32 * mix(run, twinkle * 0.5)


# ----------------------------------------------------------------- salida

def write(name, sig):
    sig = np.tanh(sig * 1.2) * 0.8
    # Rampa de 3 ms al final: sin chasquido al cortar.
    fade = min(len(sig), int(0.003 * SR))
    sig[-fade:] *= np.linspace(1, 0, fade)
    path = os.path.abspath(os.path.join(OUT_DIR, f"{name}.wav"))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((sig * 32767).astype("<i2").tobytes())
    print(f"{name:13s} {os.path.getsize(path):6d} bytes  {len(sig) / SR * 1000:.0f} ms")


def main():
    sounds = [
        ("card", card),
        ("chip", chip),
        ("chipOff", chip_off),
        ("sheetUp", sheet_up),
        ("back", back),
        ("favOn", fav_on),
        ("favOff", fav_off),
        ("tab", tab),
        ("dice", dice),
        ("toggle", toggle),
        ("morph", morph),
        ("mega", mega),
        ("success", success),
        ("error", error),
        ("battleStart", battle_start),
        ("typeNormal", t_normal),
        ("typeFire", t_fire),
        ("typeWater", t_water),
        ("typeGrass", t_grass),
        ("typeElectric", t_electric),
        ("typeIce", t_ice),
        ("typeFighting", t_fighting),
        ("typePoison", t_poison),
        ("typeGround", t_ground),
        ("typeFlying", t_flying),
        ("typePsychic", t_psychic),
        ("typeBug", t_bug),
        ("typeRock", t_rock),
        ("typeGhost", t_ghost),
        ("typeDragon", t_dragon),
        ("typeDark", t_dark),
        ("typeSteel", t_steel),
        ("typeFairy", t_fairy),
    ]
    for name, fn in sounds:
        write(name, fn())


if __name__ == "__main__":
    main()
