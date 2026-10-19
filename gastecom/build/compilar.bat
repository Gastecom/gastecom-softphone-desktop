@echo off
REM ===========================================================================
REM  Compila el softphone de PC - equipo de Izan
REM
REM  Uso:   compilar.bat        usa 3 procesos en paralelo
REM         compilar.bat 6      usa 6
REM
REM  Requiere haber pasado antes por configurar.bat.
REM
REM  Por que 3 por defecto y no 8: cada cl.exe pide entre 1 y 2 GB. Con 8 nucleos
REM  y 16 GB de RAM, lanzar 8 a la vez agota la memoria y el equipo se pone a
REM  paginar; entonces todo tarda mas que con menos procesos, ademas de dejar la
REM  maquina inservible para trabajar. El CI de GitHub usa tambien 3.
REM  Regla practica: (RAM disponible en MB - 2000) / 1500, con tope en nucleos-1.
REM
REM  El SDK completo son varias HORAS la primera vez. Despues es incremental:
REM  ninja solo recompila lo que ha cambiado, asi que iterar sobre el codigo de
REM  la aplicacion baja a segundos o minutos.
REM ===========================================================================

set "GAS_J=%~1"
if "%GAS_J%"=="" set "GAS_J=3"

call "%~dp0entorno-compilacion.bat"
if errorlevel 1 exit /b 1

set "GAS_SRC=C:\Users\izanr\gsp"
if not exist "%GAS_SRC%\build\build.ninja" (
  echo ERROR: no hay build\build.ninja. Ejecuta primero configurar.bat
  exit /b 1
)

cd /d "%GAS_SRC%"
echo.
echo === Compilando con %GAS_J% procesos en paralelo ===
echo Empezado: %DATE% %TIME%
echo.

cmake --build build --parallel %GAS_J%

if errorlevel 1 (
  echo.
  echo === LA COMPILACION HA FALLADO ===
  echo Terminado: %DATE% %TIME%
  exit /b 1
)

echo.
echo === COMPILACION CORRECTA ===
echo Terminado: %DATE% %TIME%
echo.
echo El ejecutable deberia estar en:
echo   %GAS_SRC%\build\OUTPUT\bin\gastecom-softphone.exe
