#!/usr/bin/env python3
"""
Genera los iconos de Gastecom para el softphone de escritorio.

Fuente: la marca circular de Gastecom, la misma que usan las apps de Android e
iOS, para que las tres plataformas se vean iguales en la barra de tareas.
El logotipo completo (marca + "gastecom" + eslogan) es apaisado 1000x500 y no
sirve como icono; se reserva para las pantallas de bienvenida.
"""
import base64
import os
import sys

from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(BASE)                      # .../Softphone Gastecom
APP = os.path.join(BASE, 'upstream')              # arbol del proyecto

LOGO_MARCA = os.path.join(RAIZ, 'android', 'linphone-android', 'app', 'src',
                          'main', 'res', 'drawable', 'gastecom_logo.png')
LOGO_COMPLETO = os.path.join(RAIZ, 'recursos', 'marca', 'Gastecom-ok.png')

if not os.path.exists(LOGO_MARCA):
    print(f'!! no encuentro la marca circular en {LOGO_MARCA}')
    sys.exit(1)

marca = Image.open(LOGO_MARCA).convert('RGBA')
print(f'marca circular: {marca.size}')

# Fondo blanco: el logo tiene degradados grises que desaparecen sobre oscuro.
def sobre_blanco(im, lado):
    fondo = Image.new('RGBA', (lado, lado), (255, 255, 255, 255))
    escalado = im.resize((lado, lado), Image.LANCZOS)
    fondo.alpha_composite(escalado)
    return fondo

hechos = []

# ── 1. icono Windows (.ico multi-resolucion) ────────────────────────────────
destino_ico = os.path.join(APP, 'Linphone', 'data', 'icon.ico')
if os.path.exists(destino_ico):
    tamanos = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    sobre_blanco(marca, 256).save(destino_ico, format='ICO', sizes=tamanos)
    hechos.append(f'icon.ico ({len(tamanos)} resoluciones)')

# ── 2. SVG que la interfaz carga como logo ──────────────────────────────────
# La marca es un PNG, no un trazado vectorial, asi que se envuelve en un SVG
# con la imagen embebida en base64. Se mantiene el nombre de fichero para no
# tocar las referencias del codigo.
destino_svg = os.path.join(APP, 'Linphone', 'data', 'image', 'linphone.svg')
if os.path.exists(destino_svg):
    tmp = os.path.join(BASE, '_tmp_marca.png')
    sobre_blanco(marca, 512).save(tmp, format='PNG')
    with open(tmp, 'rb') as fh:
        b64 = base64.b64encode(fh.read()).decode('ascii')
    os.remove(tmp)
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="512" height="512" viewBox="0 0 512 512">\n'
        '  <title>Gastecom</title>\n'
        f'  <image width="512" height="512" xlink:href="data:image/png;base64,{b64}"/>\n'
        '</svg>\n'
    )
    with open(destino_svg, 'w', encoding='utf-8') as fh:
        fh.write(svg)
    hechos.append('linphone.svg -> marca Gastecom embebida')

# ── 3. icono macOS (.icns), en la medida en que Pillow lo permita ───────────
destino_icns = os.path.join(APP, 'cmake', 'install', 'macos', 'linphone.icns')
if os.path.exists(destino_icns):
    try:
        sobre_blanco(marca, 1024).save(destino_icns, format='ICNS')
        hechos.append('linphone.icns')
    except Exception as e:
        print(f'  aviso: no se pudo generar el .icns ({e}); solo afecta a macOS')

# ── 4. logotipo completo para pantallas de bienvenida ──────────────────────
if os.path.exists(LOGO_COMPLETO):
    destino_dir = os.path.join(APP, 'Linphone', 'data', 'image')
    if os.path.isdir(destino_dir):
        completo = Image.open(LOGO_COMPLETO).convert('RGBA')
        completo.save(os.path.join(destino_dir, 'gastecom_logo_completo.png'))
        marca_png = sobre_blanco(marca, 256)
        marca_png.save(os.path.join(destino_dir, 'gastecom_marca.png'))
        hechos.append('gastecom_logo_completo.png + gastecom_marca.png')

print()
print('GENERADO:')
for h in hechos:
    print('  +', h)
if not hechos:
    print('  (nada: revisar rutas)')
