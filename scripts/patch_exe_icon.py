"""Troca o ícone de um executável Windows por um ICO.

Uso: python scripts/patch_exe_icon.py <exe> <ico>

O gerar_exe.ps1 concatena love.exe + game.love; como o recurso de ícone vem do
love.exe, patchamos uma cópia dele ANTES da fusão (assim o ZIP anexado nunca é
re-escrito pelo UpdateResource).
"""
import ctypes
import struct
import sys
from pathlib import Path

kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

kernel32.BeginUpdateResourceW.argtypes = [ctypes.c_wchar_p, ctypes.c_int]
kernel32.BeginUpdateResourceW.restype = ctypes.c_void_p
kernel32.UpdateResourceW.argtypes = [
    ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
    ctypes.c_ushort, ctypes.c_void_p, ctypes.c_ulong,
]
kernel32.UpdateResourceW.restype = ctypes.c_bool
kernel32.EndUpdateResourceW.argtypes = [ctypes.c_void_p, ctypes.c_int]
kernel32.EndUpdateResourceW.restype = ctypes.c_bool

RT_ICON = 3
RT_GROUP_ICON = 14


def _check(cond):
    if not cond:
        raise ctypes.WinError(ctypes.get_last_error())


def ler_ico(caminho):
    dados = Path(caminho).read_bytes()
    reservado, tipo, quantidade = struct.unpack_from("<HHH", dados, 0)
    if reservado != 0 or tipo != 1 or quantidade == 0:
        raise ValueError(f"ICO inválido: {caminho}")
    entradas = []
    for i in range(quantidade):
        larg, alt, cores, res, planos, bits, tamanho, offset = struct.unpack_from(
            "<BBBBHHII", dados, 6 + i * 16
        )
        imagem = dados[offset:offset + tamanho]
        entradas.append((larg or 256, alt or 256, planos, bits, imagem, i + 1))
    return entradas


def aplicar(exe, ico):
    entradas = ler_ico(ico)
    handle = kernel32.BeginUpdateResourceW(str(exe), False)
    _check(handle)

    # GRPICONDIR: uma entrada por imagem, apontando para os RT_ICON por id.
    grupo = struct.pack("<HHH", 0, 1, len(entradas))
    try:
        for larg, alt, planos, bits, imagem, rid in entradas:
            _check(kernel32.UpdateResourceW(
                handle, ctypes.c_void_p(RT_ICON), ctypes.c_void_p(rid),
                0, imagem, len(imagem),
            ))
            grupo += struct.pack(
                "<BBBBHHIH",
                larg if larg < 256 else 0,
                alt if alt < 256 else 0,
                0, 0, planos, bits, len(imagem), rid,
            )
        _check(kernel32.UpdateResourceW(
            handle, ctypes.c_void_p(RT_GROUP_ICON), ctypes.c_void_p(1),
            0, grupo, len(grupo),
        ))
    finally:
        _check(kernel32.EndUpdateResourceW(handle, False))

    print(f"Ícone aplicado: {exe} ({len(entradas)} tamanhos)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Uso: patch_exe_icon.py <exe> <ico>")
    aplicar(Path(sys.argv[1]), Path(sys.argv[2]))
