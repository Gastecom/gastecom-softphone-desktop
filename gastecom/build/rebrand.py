#!/usr/bin/env python3
"""
Rebranding de linphone-desktop a Gastecom Softphone.

QUE SE CAMBIA: todo lo que ve el usuario -- nombre de la aplicacion y del
ejecutable, identificador, fabricante, URLs, metadatos del instalador en las
tres plataformas, iconos y la configuracion de fabrica, que pasa a apuntar al
SBC de Gastecom en AWS igual que las apps de Android e iOS.

QUE NO SE TOCA, Y POR QUE:

  1. Las cabeceras "This file is part of linphone-desktop" de los .cpp/.hpp.
     Son las cabeceras de licencia GPLv3. La GPL permite rebrandear y
     redistribuir, pero obliga a conservar la atribucion y el aviso de licencia.
     Borrarlas seria una infraccion, y ademas no aporta nada: el usuario final
     no las ve.

  2. El modulo QML interno se llama "Linphone" (176 'import Linphone' y ~120
     rutas 'qrc:/qt/qml/Linphone/...'). Renombrarlo obliga a tocar la estructura
     de recursos Qt entera, con riesgo alto de romper la compilacion y cero
     impacto visible. Es un nombre de espacio de nombres, no una marca en
     pantalla.

Ejecutar desde la carpeta Desktop. Es idempotente.
"""
import os
import re
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(BASE, 'upstream')

NOMBRE = "Gastecom Softphone"
EJECUTABLE = "gastecom-softphone"
ID_APP = "es.gastecom.softphone"
FABRICANTE = "Gastecom"
URL = "https://www.gastecom.es"
DESCRIPCION = "Softphone corporativo de Gastecom"
SBC = "sbcsoftphone.gastecom.es"

cambios = []
fallos = []


def editar(rel, reemplazos, obligatorio=True):
    """Aplica (viejo, nuevo) sobre un fichero. Solo cuenta si algo cambia."""
    ruta = os.path.join(APP, rel)
    if not os.path.exists(ruta):
        (fallos if obligatorio else []).append(f'{rel}: no existe')
        return
    with open(ruta, encoding='utf-8', errors='replace') as fh:
        txt = fh.read()
    orig = txt
    aplicados = 0
    for viejo, nuevo in reemplazos:
        if viejo in txt:
            txt = txt.replace(viejo, nuevo)
            aplicados += 1
    if txt != orig:
        with open(ruta, 'w', encoding='utf-8') as fh:
            fh.write(txt)
        cambios.append(f'{rel} ({aplicados} sustituciones)')


# ── 1. identidad de la aplicacion ───────────────────────────────────────────
editar('CMakeLists.txt', [
    ('set(LINPHONEAPP_APPLICATION_NAME "Linphone" CACHE STRING "Application name" )',
     f'set(LINPHONEAPP_APPLICATION_NAME "{NOMBRE}" CACHE STRING "Application name" )'),
    ('set(LINPHONEAPP_EXECUTABLE_NAME "linphone" CACHE STRING "Executable name" )',
     f'set(LINPHONEAPP_EXECUTABLE_NAME "{EJECUTABLE}" CACHE STRING "Executable name" )'),
])

editar('Linphone/application_info.cmake', [
    ('set(APPLICATION_DESCRIPTION "A libre SIP client")',
     f'set(APPLICATION_DESCRIPTION "{DESCRIPCION}")'),
    ('set(APPLICATION_ID "com.belledonnecommunications.${LINPHONEAPP_EXECUTABLE_NAME}")',
     f'set(APPLICATION_ID "{ID_APP}")'),
    ('set(APPLICATION_URL "https://www.linphone.org")',
     f'set(APPLICATION_URL "{URL}")'),
    ('set(APPLICATION_VENDOR "Belledonne Communications")',
     f'set(APPLICATION_VENDOR "{FABRICANTE}")'),
])

# ── 2. metadatos de instalador (lo que se ve al instalar) ──────────────────
for rel in ('cmake/install/linux/linphone.desktop.cmake',
            'cmake/install/macos/Info.plist.in',
            'cmake/install/windows/appDetailsWindows.rc.in',
            'cmake/install/windows/install.nsi.in',
            'cmake/install/windows/uninstall.nsi.in'):
    editar(rel, [
        ('Belledonne Communications', FABRICANTE),
        ('https://www.linphone.org', URL),
        ('linphone.org', 'gastecom.es'),
        ('A libre SIP client', DESCRIPCION),
    ], obligatorio=False)

# ── 3. configuracion de fabrica: apuntar al SBC de Gastecom ────────────────
# Misma configuracion que Android e iOS: TLS 5091 contra el SBC de AWS y SRTP.
# Se retiran los servicios de linphone.org (alta de cuentas, RLS, LIME, envio
# de logs): esta app se aprovisiona contra el SBC de Gastecom, no contra ellos.
factory = f"""[app]
record_aware=1

[misc]
aggregate_imdn=1
hide_empty_chat_rooms=1
# Servicios de terceros desactivados: este softphone solo habla con el SBC de
# Gastecom. Dejarlos activos filtraria datos de uso a servidores ajenos.
log_collection_upload_server_url=
file_transfer_server_url=
version_check_url_root=

[net]
force_ice_disablement=0
mtu=1300

[rtp]
accept_any_encryption=1

[sip]
auto_answer_replacing_calls=1
auto_net_state_mon=1
guess_hostname=1
ping_with_options=0
register_only_when_network_is_up=1
use_cpim=1
# SRTP (SDES): es el unico modo verificado contra el SBC. rtpengine reenvia los
# paquetes SRTP de forma opaca; las claves viajan en el SDP protegido por TLS.
media_encryption=srtp
media_encryption_mandatory=0

[sound]
ec_filter=MSWebRTCAEC

[ui]
use_qrcode=0

[video]
auto_resize_preview_to_keep_ratio=1
max_conference_size=vga
other_display_mode=Hybrid

[proxy_default_values]
# El tecnico crea el perfil en el portal de provisioning y entrega usuario y
# contrasena; el dominio y la ruta ya vienen fijados aqui.
reg_proxy=<sip:{SBC}:5091;transport=tls>
reg_route=<sip:{SBC}:5091;transport=tls;lr>
reg_expires=3600
reg_sendregister=1
publish=0
quality_reporting_enabled=0
avpf_rr_interval=5000

[assistant]
password_min_length=6
"""

ruta_factory = os.path.join(APP, 'Linphone/data/config/linphonerc-factory')
if os.path.exists(ruta_factory):
    with open(ruta_factory, 'w', encoding='utf-8') as fh:
        fh.write(factory)
    cambios.append('linphonerc-factory reescrito (SBC Gastecom, sin servicios de terceros)')
else:
    fallos.append('linphonerc-factory: no existe')

# ── 4. cadenas visibles que nombran a Linphone ─────────────────────────────
# Son pocas: el grueso de 'Linphone' en QML son imports del modulo interno.
patron_visible = re.compile(r'qsTr\("([^"]*Linphone[^"]*)"\)')
tocados = 0
for raiz, _, ficheros in os.walk(os.path.join(APP, 'Linphone')):
    for f in ficheros:
        if not f.endswith('.qml'):
            continue
        ruta = os.path.join(raiz, f)
        with open(ruta, encoding='utf-8', errors='replace') as fh:
            txt = fh.read()
        nuevo = patron_visible.sub(
            lambda m: 'qsTr("' + m.group(1).replace('Linphone', 'Gastecom') + '")', txt)
        if nuevo != txt:
            with open(ruta, 'w', encoding='utf-8') as fh:
                fh.write(nuevo)
            tocados += 1
if tocados:
    cambios.append(f'cadenas visibles qsTr() en {tocados} ficheros QML')

# ── informe ────────────────────────────────────────────────────────────────
print('CAMBIOS APLICADOS:')
for c in cambios:
    print('  +', c)
if fallos:
    print('\nNO ENCONTRADOS:')
    for f in fallos:
        print('  -', f)
print(f'\nTotal: {len(cambios)} bloques modificados')
