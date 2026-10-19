@echo off
REM ===========================================================================
REM  Entorno de compilacion del softphone de PC - equipo de Izan
REM
REM  Creado el 2026-08-07, cuando IT levanto el bloqueo de AppLocker. Hasta ese
REM  dia cmake.exe y qmake.exe daban "Permission denied" y no se podia compilar
REM  aqui. Ver Desktop/CLAUDE.md.
REM
REM  Uso:   entorno-compilacion.bat
REM
REM  Replica el entorno del CI de GitHub, .github/workflows/build-pc.yml, que
REM  es donde se descubrieron a unos 90 minutos por ciclo las trampas de abajo.
REM  Si tocas una, lee antes su comentario.
REM
REM  OJO con la sintaxis de cmd: nada de parentesis dentro de REM y nada de
REM  etiquetas dinamicas dentro de un FOR. La primera version de este fichero
REM  fallaba por las dos cosas.
REM ===========================================================================

REM Se localiza vcvars64.bat con vswhere en vez de una ruta fija: la carpeta
REM de version de Visual Studio cambia segun el equipo -aqui es "2022", en
REM otro puede ser "18"-. Se pide el componente x86/x64, que es el toolset
REM v143 que necesita VP8/VP9. Anadido el 2026-08-19 al montar el entorno en
REM el equipo de pruebas 192.168.111.199, donde la ruta cableada no existia.
REM Sin "if exist (...)" alrededor del FOR: no hace falta -vswhere siempre
REM esta si el Instalador de VS esta presente- y asi hay un nivel menos de
REM parentesis anidados con una ruta que lleva "(x86)" en el nombre.
REM
REM AVISO CONOCIDO, no es de esta linea: al llamar a vcvars64.bat un poco
REM mas abajo puede salir un "vswhere.exe no se reconoce" en pantalla. Viene
REM de DENTRO del propio vcvars64.bat de Microsoft -llama a vswhere otra vez
REM el solo, para localizar el SDK, y en este PATH tropieza un instante-. Se
REM autocorrige enseguida: GAS_VS_PATH ya quedo bien puesto por el FOR de
REM aqui arriba, y el resultado final (link.exe, MSBuild.exe) sale correcto.
REM Comprobado con marcadores de echo el 2026-08-19: el aviso aparece
REM DESPUES de que este bloque termine, no puede venir de el.
set "GAS_VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
set "GAS_VS_PATH="
for /f "usebackq tokens=*" %%i in (`"%GAS_VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do set "GAS_VS_PATH=%%i"
if not defined GAS_VS_PATH (
  echo ERROR: vswhere no encontro ninguna instalacion de Visual Studio con el toolset MSVC v143 ^(componente VC.Tools.x86.x64^).
  exit /b 1
)
call "%GAS_VS_PATH%\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 (
  echo ERROR: no se pudo cargar el entorno de MSVC.
  exit /b 1
)

REM  nasm y yasm viven en una ruta SIN ESPACIOS a proposito. El makefile de
REM  openh264 expande $ASM sin comillas dentro de la receta, y con una ruta
REM  como "C:\Program Files\..." el shell la parte por el espacio y falla con
REM  "C:/Program: No such file or directory". Costo un ciclo entero en el CI.
set "GAS_TOOLS=C:\Users\izanr\devtools\bin"
set "GAS_PY_SCRIPTS=C:\Users\izanr\AppData\Roaming\Python\Python314\Scripts"

REM  ORDEN DEL PATH - es la parte delicada. Dos necesidades opuestas:
REM
REM   1. El bin de Git por delante de System32. libvpx ejecuta gen_msvs_def.sh,
REM      cuyo shebang es #!/bin/bash, y quien resuelve ese bash es make, un
REM      proceso NATIVO de Windows. Sin esto encuentra System32\bash.exe, el
REM      lanzador de WSL, y muere con "Windows Subsystem for Linux has no
REM      installed distributions".
REM
REM   2. MSVC por delante del bin de Git. Git trae su PROPIO link.exe, el de
REM      coreutils, que NO es un enlazador, y meson aborta al configurar dav1d
REM      con "Found GNU link.exe instead of MSVC link.exe".
REM
REM  Orden final:  MSVC  antes que  Git\usr\bin  antes que  System32
REM  Equivocarse aqui no da un error claro: da un fallo a los 40 minutos que
REM  no apunta a la causa. Por eso se comprueba el efecto mas abajo.
REM  make viene de MSYS2, no de Git: Git para Windows NO trae make. libvpx y
REM  openh264 se compilan con autotools y su build.sh llama a `make` a secas,
REM  asi que sin esto el build muere con
REM    EP_vpx_build.sh: line 8: make: command not found
REM  Se instalo con  pacman -S make  el 2026-08-07. Si algun dia falta, ese es
REM  el comando; ojo, pacman no puede descargar en esta red por la inspeccion
REM  TLS, pero el paquete ya estaba en la cache local.
REM
REM  Va DESPUES de MSVC en el PATH final, igual que el bin de Git: MSYS2 tambien
REM  trae su propio link.exe de coreutils y no debe ganarle al enlazador.
REM  MSBuild. vcvars64.bat NO lo pone en el PATH, y libvpx lo necesita: su
REM  target de Windows es "x86_64-win64-vsNN", asi que `make` solo GENERA los
REM  .vcxproj y delega la compilacion real en MSBuild desde msvs_common.sh.
REM  Sin esto, libvpx avisa y sigue como si nada:
REM    * msbuild.exe not found in path.
REM    * Skipping build of Release^|x64 (msbuild.exe not in path)
REM  y el build muere mucho despues, al enlazar mediastreamer2, con
REM    LNK1181: no se puede abrir el archivo de entrada 'OUTPUT\lib\x64\vpxmd.lib'
REM  El aviso de libvpx queda enterrado en su log de stamp, asi que el sintoma
REM  aparece a 1300 tareas de distancia de la causa.
set "PATH=%GAS_VS_PATH%\MSBuild\Current\Bin;%PATH%"
REM  MSYS2 va DELANTE del bin de Git, y esto es deliberado: si `sh` es el de Git
REM  pero `make` el de MSYS2, hay DOS runtimes con raices distintas traduciendo
REM  la misma ruta. Git resuelve /tmp a "C:\Program Files\Git\tmp" y MSYS2 a
REM  "C:\msys64\tmp". El sh de Git fuerza TMP=/tmp, make lo hereda, y al lanzar
REM  MSBuild la traduccion no cuadra: TMP le llega invalido, .NET cae a su
REM  recurso final que es %SystemRoot%, y sin ser administrador revienta con
REM    MSB1025 / UnauthorizedAccessException: Acceso denegado a la ruta
REM    'C:\WINDOWS\MSBuildTemp...'
REM  Con MSYS2 por delante, sh, bash y make son del MISMO runtime y /tmp apunta
REM  a un unico sitio que existe. Sigue cumpliendose lo importante: MSVC va
REM  antes que todo esto, asi que `link` no es el de coreutils.
set "PATH=C:\Program Files\Git\usr\bin;%PATH%"
set "PATH=C:\msys64\usr\bin;%PATH%"
REM  makensis.exe (instalador NSIS, pacman -Sy mingw-w64-x86_64-nsis el
REM  2026-08-20) vive en mingw64\bin, no en usr\bin. Solo hace falta para
REM  empaquetar (ENABLE_APP_PACKAGING=ON), pero anadirlo siempre no rompe nada
REM  de lo demas.
set "PATH=C:\msys64\mingw64\bin;%PATH%"
set "PATH=%GAS_TOOLS%;%GAS_PY_SCRIPTS%;%PATH%"

REM CMake, Ninja, doxygen y Python/meson portatiles, instalados el 2026-08-19
REM sin admin en el equipo de pruebas 192.168.111.199 (winget y el instalador
REM de python.org estaban bloqueados en esa red -Fortiguard SDNS-, asi que se
REM bajaron como zip/exe sueltos de GitHub). Se anaden SOLO si la carpeta
REM existe, para no pisar una instalacion normal en otra maquina que ya los
REM tenga por el camino de siempre.
set "GAS_PORTABLE=C:\Users\izanr\softphone-pruebas\_herramientas"
if exist "%GAS_PORTABLE%\cmake\cmake-4.0.2-windows-x86_64\bin" set "PATH=%GAS_PORTABLE%\cmake\cmake-4.0.2-windows-x86_64\bin;%PATH%"
if exist "%GAS_PORTABLE%\ninja" set "PATH=%GAS_PORTABLE%\ninja;%PATH%"
if exist "%GAS_PORTABLE%\doxygen" set "PATH=%GAS_PORTABLE%\doxygen;%PATH%"
if exist "%GAS_PORTABLE%\python" set "PATH=%GAS_PORTABLE%\python;%GAS_PORTABLE%\python\Scripts;%PATH%"

for /f "delims=" %%i in ('where cl.exe') do set "GAS_CL_DIR=%%~dpi"
set "PATH=%GAS_CL_DIR%;%PATH%"

REM  curl para las descargas del build. rnnoise baja su modelo con `curl -L -o`
REM  desde download.linphone.org y en este equipo falla con
REM  CRYPT_E_NO_REVOCATION_CHECK: el backend schannel no consigue consultar el
REM  punto de revocacion, seguramente por la inspeccion TLS de la red.
REM  CURL_HOME apunta a un _curlrc con ssl-no-revoke, asi que el ajuste vale
REM  SOLO para esta consola. No se toca %APPDATA%\_curlrc, que lo aplicaria a
REM  todo el equipo.
set "CURL_HOME=%~dp0curl-config"

echo.
echo === Comprobacion del entorno ===
call :mostrar link
call :mostrar bash
call :mostrar make
call :mostrar msbuild
call :mostrar cmake
call :mostrar ninja
call :mostrar meson
call :mostrar nasm
call :mostrar yasm
call :mostrar perl
call :mostrar doxygen
echo.
echo Entorno listo.
goto :eof

:mostrar
set "GAS_HIT="
for /f "delims=" %%i in ('where %1 2^>nul') do if not defined GAS_HIT set "GAS_HIT=%%i"
if defined GAS_HIT echo   %1 -^> %GAS_HIT%
if not defined GAS_HIT echo   %1 -^> NO ENCONTRADO
goto :eof
