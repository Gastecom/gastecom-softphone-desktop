#!/usr/bin/env python3
"""
Rellena las traducciones de un fichero .ts de Qt a partir de lotes en JSON.

Uso:  python3 inyectar_traducciones.py <idioma.ts> <en.ts> <carpeta_lotes>

Por que existe: es.ts venia con las 1190 cadenas vacias y marcadas
type="unfinished". El <source> de estos ficheros NO es texto ingles, es una
CLAVE (por ejemplo "save"), asi que para traducir hay que mirar el texto
ingles en en.ts. Este script hace esa union:

    clave  --en.ts-->  texto ingles  --lote.json-->  texto español

Los lotes son {texto_ingles: texto_español}. Se aplican todos los .json de la
carpeta, asi que se puede ir traduciendo por tandas sin perder lo anterior.

Verifica el EFECTO: al terminar cuenta cuantas cadenas quedan sin traducir
leyendo de nuevo el fichero, en vez de fiarse de lo que crea haber escrito.
"""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET


def cargar_ingles(ruta_en):
    """clave -> texto ingles"""
    raiz = ET.parse(ruta_en).getroot()
    m = {}
    for ctx in raiz.findall("context"):
        for msg in ctx.findall("message"):
            clave = msg.findtext("source") or ""
            texto = msg.findtext("translation") or ""
            if clave and texto:
                m[clave] = texto
    return m


def cargar_lotes(carpeta):
    """texto ingles -> texto español, uniendo todos los lotes"""
    tr = {}
    for f in sorted(pathlib.Path(carpeta).glob("*.json")):
        tr.update(json.load(open(f, encoding="utf-8")))
    return tr


def main():
    ts_destino, ts_ingles, carpeta = sys.argv[1], sys.argv[2], sys.argv[3]
    ingles = cargar_ingles(ts_ingles)
    trad = cargar_lotes(carpeta)
    print(f"referencia inglesa: {len(ingles)} claves")
    print(f"traducciones disponibles: {len(trad)}")

    arbol = ET.parse(ts_destino)
    raiz = arbol.getroot()
    puestas = sin_ingles = sin_traduccion = ya_estaban = 0

    for ctx in raiz.findall("context"):
        for msg in ctx.findall("message"):
            clave = msg.findtext("source") or ""
            nodo = msg.find("translation")
            if nodo is None:
                continue
            pendiente = nodo.get("type") == "unfinished" or not (nodo.text or "").strip()
            if not pendiente:
                ya_estaban += 1
                continue
            en = ingles.get(clave)
            if not en:
                sin_ingles += 1
                continue
            es = trad.get(en)
            if not es:
                sin_traduccion += 1
                continue
            nodo.text = es
            if "type" in nodo.attrib:
                del nodo.attrib["type"]  # deja de ser unfinished: lrelease ya la incluye
            puestas += 1

    # ET no conserva el DOCTYPE, y los .ts lo llevan. Se reescribe a mano.
    cuerpo = ET.tostring(raiz, encoding="unicode")
    with open(ts_destino, "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n')
        fh.write(cuerpo)

    print(f"\naplicadas ahora        : {puestas}")
    print(f"ya estaban traducidas  : {ya_estaban}")
    print(f"sin traduccion todavia : {sin_traduccion}")
    print(f"sin referencia inglesa : {sin_ingles}")

    # Comprobacion del efecto: releer el fichero recien escrito.
    raiz2 = ET.parse(ts_destino).getroot()
    total = faltan = 0
    for ctx in raiz2.findall("context"):
        for msg in ctx.findall("message"):
            nodo = msg.find("translation")
            if nodo is None:
                continue
            total += 1
            if nodo.get("type") == "unfinished" or not (nodo.text or "").strip():
                faltan += 1
    hechas = total - faltan
    print(f"\nrelectura: {hechas}/{total} traducidas ({hechas * 100 // total}%)")


if __name__ == "__main__":
    main()
