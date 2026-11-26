"""Gera os ícones de launcher (Android) e o ICO (Windows) a partir da arte Tormentalia.

Uso: python scripts/gerar_icons.py
"""
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
ORIGEM = RAIZ / "arte" / "deus_mercado" / "logo.png"
RES = RAIZ / "android-res"
ICO_DIR = RAIZ / "build" / "icons"

# Tamanhos de launcher por densidade (dp -> px, 48dp base)
DENSIDADES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def main():
    if not ORIGEM.exists():
        raise SystemExit(f"Arte não encontrada: {ORIGEM}")

    src = Image.open(ORIGEM).convert("RGBA")

    for densidade, tamanho in DENSIDADES.items():
        destino = RES / f"drawable-{densidade}" / "tormentalia_icon.png"
        destino.parent.mkdir(parents=True, exist_ok=True)
        src.resize((tamanho, tamanho), Image.LANCZOS).save(destino)
        print(f"Android {densidade:8s} {tamanho}x{tamanho}: {destino}")

    # fallback sem qualificador (para ferramentas que ignoram densidade)
    fallback = RES / "drawable" / "tormentalia_icon.png"
    fallback.parent.mkdir(parents=True, exist_ok=True)
    src.resize((96, 96), Image.LANCZOS).save(fallback)

    ICO_DIR.mkdir(parents=True, exist_ok=True)
    ico = ICO_DIR / "tormentalia.ico"
    # ICO com vários tamanhos; Windows escolhe o melhor para cada contexto.
    src.save(ico, format="ICO", sizes=[(16, 16), (24, 24), (32, 32),
                                       (48, 48), (64, 64), (128, 128),
                                       (256, 256)])
    print(f"Windows ICO: {ico}")


if __name__ == "__main__":
    main()
