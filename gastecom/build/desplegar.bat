@echo off
REM ===========================================================================
REM  Despliega el runtime de Qt sobre el binario ya instalado - equipo de Izan
REM
REM  Uso:   desplegar.bat
REM  Requiere haber pasado antes por: configurar.bat -> compilar.bat -> cmake --install
REM
REM  IMPRESCINDIBLE antes de ejecutar el .exe en local. Sin este paso el
REM  binario falla con STATUS_DLL_NOT_FOUND: `cmake --install` copia la app y
REM  sus propias DLL (liblinphone, mediastreamer2...) a OUTPUT/, pero no sabe
REM  nada del runtime de Qt. Eso lo copia windeployqt, que viene con Qt y no
REM  se ejecuta solo. Mismo motivo que en el paso equivalente del CI
REM  (.github/workflows/build-pc.yml, anadido el 2026-08-19: el artefacto no
REM  arrancaba en ninguna maquina hasta que se le puso este paso).
REM
REM  Recreado el 2026-08-19: este fichero estaba a 0 bytes, roto desde el
REM  17/08, antes de esta sesion.
REM ===========================================================================

set "GAS_SRC=C:\Users\izanr\gsp"
set "GAS_EXE=%GAS_SRC%\build\OUTPUT\bin\gastecom-softphone.exe"

if not exist "%GAS_EXE%" (
  echo ERROR: no existe %GAS_EXE%
  echo Ejecuta antes: configurar.bat, compilar.bat, y "cmake --install build"
  exit /b 1
)

REM  windeployqt viene con la instalacion normal de Qt. Si algun dia Qt se
REM  instala en otra ruta, cambiar solo esta linea.
set "GAS_WINDEPLOYQT=C:\Qt\6.8.3\msvc2022_64\bin\windeployqt.exe"
if not exist "%GAS_WINDEPLOYQT%" (
  echo ERROR: no se encuentra windeployqt.exe en %GAS_WINDEPLOYQT%
  exit /b 1
)

echo.
echo === Desplegando el runtime de Qt sobre %GAS_EXE% ===
echo.

REM  --qmldir es obligatorio: la interfaz es QML. Sin el copia las DLL de C++
REM  pero no los modulos QML, y la ventana sale en blanco.
REM  NO se pasa --no-opengl-sw: opengl32sw.dll es el respaldo por software
REM  para PCs sin driver de GPU decente.
REM  NO se pasa --no-translations: son las que traducen los dialogos
REM  estandar de Qt al espanol.
"%GAS_WINDEPLOYQT%" "%GAS_EXE%" --qmldir "%GAS_SRC%\Linphone\view" --release

if errorlevel 1 (
  echo.
  echo === EL DESPLIEGUE HA FALLADO ===
  exit /b 1
)

REM  Comprobacion dura: que windeployqt salga con 0 no garantiza que esten
REM  las 9 DLL. Es justo el fallo que paso desapercibido en el CI hasta que
REM  alguien intento ejecutar el zip en otra maquina.
set "GAS_FALTAN=0"
for %%d in (Qt6Core Qt6Gui Qt6Network Qt6NetworkAuth Qt6OpenGL Qt6Qml Qt6Quick Qt6Svg Qt6Widgets) do (
  if not exist "%GAS_SRC%\build\OUTPUT\bin\%%d.dll" (
    echo ERROR: falta %%d.dll junto al ejecutable
    set /a GAS_FALTAN+=1
  )
)
if not "%GAS_FALTAN%"=="0" (
  echo.
  echo === EL BINARIO NO ARRANCARIA: faltan %GAS_FALTAN% DLL de Qt ===
  exit /b 1
)

echo.
echo === DESPLIEGUE CORRECTO ===
echo Las 9 DLL de Qt estan junto al ejecutable.
echo.
echo Para ejecutar:
echo   %GAS_SRC%\build\OUTPUT\bin\gastecom-softphone.exe
