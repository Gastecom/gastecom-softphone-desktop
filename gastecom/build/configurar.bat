@echo off
REM ===========================================================================
REM  Configura el proyecto con CMake - equipo de Izan
REM
REM  Uso:   configurar.bat                sin VPX, es lo que este equipo puede compilar
REM         configurar.bat ON             con VPX, exige el toolset v143 instalado
REM         configurar.bat ON ON          con VPX y generando el instalador NSIS
REM
REM  El 2o argumento (ENABLE_APP_PACKAGING) genera cmake/install/windows/*.nsi.in
REM  -ya trae la marca de Gastecom via application_info.cmake, no hay que tocarlo-
REM  como paso de "cmake --install". Exige makensis.exe (mingw-w64-x86_64-nsis,
REM  instalado con pacman el 2026-08-20; vive en msys64\mingw64\bin, no en usr\bin).
REM
REM  OJO con la sintaxis de cmd: nada de parentesis ni de caracteres no ASCII
REM  dentro de REM. Ya rompio este fichero una vez y esta documentado tambien en
REM  entorno-compilacion.bat. Si necesitas escribir algo entre parentesis, usa
REM  guiones o comillas.
REM
REM  Los flags son los que costo 12 iteraciones dar con ellos en el CI. Estan
REM  explicados en la memoria softphone-pc-ci-github y en el workflow
REM  .github/workflows/build-pc.yml. Resumen de los no obvios:
REM
REM   - LINPHONESDK_<X>_PROGRAM: el SDK no usa los nombres estandar de CMake.
REM     linphone_sdk_check_is_installed construye ese nombre, asi que
REM     -DDOXYGEN_EXECUTABLE y compania no los lee nadie.
REM   - NASM_PROGRAM a secas: openh264 lo busca por su cuenta, con otro nombre.
REM   - ENABLE_CRASH_HANDLER=OFF: si no, crashpad exige las depot-tools de
REM     Chromium.
REM   - LINPHONEAPP_VERSION: si no, git describe aborta.
REM   - ENABLE_UPDATE_CHECK=OFF: politica de Gastecom, nunca ON. Consulta
REM     download.linphone.org al arrancar y ofrece descargar el Linphone
REM     original encima del nuestro.
REM ===========================================================================

REM  Solo se aceptan ON y OFF. Sin esta comprobacion, cualquier argumento suelto
REM  se colaba tal cual como -DENABLE_VPX=<lo que sea> y CMake lo tomaba por
REM  falso sin avisar. Lo descubri pasando "--dry" en una prueba en seco.
set "GAS_VPX=%~1"
if "%GAS_VPX%"=="" set "GAS_VPX=OFF"
if /I not "%GAS_VPX%"=="ON" if /I not "%GAS_VPX%"=="OFF" (
  echo ERROR: argumento no valido "%GAS_VPX%". Usa ON, OFF, o nada para OFF.
  exit /b 1
)
set "GAS_PACKAGE=%~2"
if "%GAS_PACKAGE%"=="" set "GAS_PACKAGE=OFF"
if /I not "%GAS_PACKAGE%"=="ON" if /I not "%GAS_PACKAGE%"=="OFF" (
  echo ERROR: argumento no valido "%GAS_PACKAGE%". Usa ON, OFF, o nada para OFF.
  exit /b 1
)

call "%~dp0entorno-compilacion.bat"
if errorlevel 1 exit /b 1

REM  SE COMPILA A TRAVES DE UNA UNION DE DIRECTORIOS, no de la ruta real.
REM
REM  La ruta real contiene un espacio, en "Softphone Gastecom", y la macro
REM  qt6_add_translations de Qt 6.8.3 no la entrecomilla. El configure moria con
REM  una decena de errores "get_target_property called with non-existent target"
REM  cuyo nombre de objetivo era la COLA de la ruta a partir del espacio: Qt la
REM  partia en dos. En el CI no ocurre porque alli el directorio de trabajo es
REM  D:\a\gastecom-softphone-pc, sin espacios.
REM
REM  mklink /J no necesita permisos de administrador. Apunta al mismo directorio
REM  fisico, asi que lo que se compila es el arbol de siempre.
set "GAS_SRC=C:\Users\izanr\gsp"
if not exist "%GAS_SRC%\CMakeLists.txt" (
  mklink /J "%GAS_SRC%" "%~dp0upstream" >nul
  if errorlevel 1 (
    echo ERROR: no se pudo crear la union %GAS_SRC%
    exit /b 1
  )
)
cd /d "%GAS_SRC%"

set "GAS_TOOLS=C:\Users\izanr\devtools\bin"
set "GAS_PY=C:\Users\izanr\AppData\Roaming\Python\Python314\Scripts"

REM  Respaldo a herramientas portatiles: si no esta la ruta de siempre del
REM  equipo original -pip global, doxygen y 7-Zip instalados con su
REM  instalador normal-, se usa lo que se monto sin admin el 2026-08-19 en el
REM  equipo de pruebas 192.168.111.199. Con "if not exist" a secas, sin
REM  bloque de parentesis: mismo motivo que en entorno-compilacion.bat.
if not exist "%GAS_PY%\meson.exe" set "GAS_PY=C:\Users\izanr\softphone-pruebas\_herramientas\python\Scripts"
set "GAS_DOXYGEN=C:\Program Files\doxygen\bin\doxygen.exe"
if not exist "%GAS_DOXYGEN%" set "GAS_DOXYGEN=C:\Users\izanr\softphone-pruebas\_herramientas\doxygen\doxygen.exe"
set "GAS_7Z=C:\Program Files\7-Zip\7z.exe"
if not exist "%GAS_7Z%" set "GAS_7Z=C:\Users\izanr\devtools\7zip\7z.exe"

REM  ================== VPX DESACTIVADO POR DEFECTO EN LOCAL ==================
REM
REM  AVISO: el binario que sale de aqui NO ES IDENTICO al del CI. Le falta el
REM  codec de video VP8/VP9. H264 mediante openh264 si esta, asi que el video
REM  sigue funcionando. Para probar registro SIP, agenda LDAP, guard de
REM  aprovisionamiento o almacenamiento de contrasena da exactamente igual.
REM  LO QUE SE DISTRIBUYA DEBE SALIR DEL CI, que si compila VPX.
REM
REM  Por que: libvpx en Windows no se compila con make. Genera proyectos
REM  .vcxproj y los construye con MSBuild. Este equipo solo tiene el toolset
REM  v145, de Visual Studio 18. libvpx genera para v141 -VS 2017- porque el SDK
REM  no reconoce el toolset nuevo y cae a su valor por defecto, y como maximo
REM  soporta v143 -VS 2022-. El error es:
REM    error MSB8020: No se pueden encontrar las herramientas de compilacion
REM    para Visual Studio 2017, conjunto de herramientas v141
REM  Ni v141 ni v143 estan instalados, asi que no hay flag que lo arregle.
REM
REM  Para paridad completa con el CI: instalar "MSVC v143 - VS 2022 C++ build
REM  tools" desde el instalador de Visual Studio, requiere administrador, y
REM  luego lanzar  configurar.bat ON
REM  ==========================================================================
echo.
if /I "%GAS_VPX%"=="OFF" echo [AVISO] VPX desactivado. Binario local SIN VP8/VP9. Para distribuir, usar el CI.
if /I "%GAS_VPX%"=="ON"  echo VPX activado. Requiere el toolset v143 instalado.
echo.

REM  Certificado de firma propio de Gastecom (autofirmado, 2026-08-20).
REM  Verificado en pantalla: firma+instalacion silenciosa+arranque OK, y con
REM  el .cer publico instalado como "de confianza" (ROOT+TrustedPublisher) la
REM  firma pasa de "error desconocido" a "Firma comprobada". Vive en
REM  secretos\, no en el repo -son credenciales, igual que gastecom-release.jks
REM  o Par de claves AWS-. Solo se usa si la carpeta existe; en cualquier otro
REM  equipo el empaquetado sale sin firmar y sin fallar (el install.cmake del
REM  SDK lo detecta solo si encuentra linphone.pfx + passphrase.txt en
REM  LINPHONE_WINDOWS_SIGNING_DIR). Backup pendiente: por ahora solo vive
REM  aqui, mismo riesgo que se avisa para el keystore de Android.
set "GAS_SIGNING_DIR=C:\Users\izanr\Documents\ClaudeAI\Gastecom\secretos\Certificado firma PC Softphone"
set "GAS_SIGNING_FLAG="
REM  La ruta lleva espacios ("Certificado firma PC Softphone"): sin comillas
REM  ALREDEDOR DEL VALOR (no solo de la ruta original), cmd corta el flag en
REM  el primer espacio y CMake solo ve "...Certificado" -paso por esto el
REM  2026-08-20, misma familia de bug que el del nombre del paquete sin
REM  comillas en packaging.cmake.in-.
if exist "%GAS_SIGNING_DIR%\linphone.pfx" set GAS_SIGNING_FLAG=-DLINPHONE_WINDOWS_SIGNING_DIR="%GAS_SIGNING_DIR:\=/%"

REM  Parches Gastecom sobre external\linphone-sdk (submodulo vendorizado).
REM  Viven fuera del submodulo, en Desktop\patches\, para que sobrevivan a un
REM  "git submodule update" y queden a la vista en el git diff de este repo -
REM  antes se editaba el fichero del submodulo a mano y el fix desaparecia
REM  sin avisar si alguien actualizaba el SDK. Idempotente: si ya esta
REM  aplicado no hace nada.
py "%~dp0patches\apply_all.py"
if errorlevel 1 (
  echo.
  echo === LOS PARCHES DE linphone-sdk HAN FALLADO ===
  echo Revisar arriba antes de continuar: el binario podria salir sin el fix
  echo de nombres vacios en contactos LDAP.
  exit /b 1
)

cmake -S . -B build -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl -DCMAKE_RC_COMPILER=rc ^
  -DCMAKE_PREFIX_PATH=C:/Qt/6.8.3/msvc2022_64 ^
  -DLINPHONESDK_PLATFORM=Desktop ^
  -DLINPHONESDK_DOXYGEN_PROGRAM="%GAS_DOXYGEN:\=/%" ^
  -DLINPHONESDK_NASM_PROGRAM="%GAS_TOOLS:\=/%/nasm.exe" ^
  -DLINPHONESDK_YASM_PROGRAM="%GAS_TOOLS:\=/%/yasm.exe" ^
  -DLINPHONESDK_PERL_PROGRAM="C:/Program Files/Git/usr/bin/perl.exe" ^
  -DLINPHONESDK_MESON_PROGRAM="%GAS_PY:\=/%/meson.exe" ^
  -DLINPHONESDK_NINJA_PROGRAM="%GAS_PY:\=/%/ninja.exe" ^
  -D7Z_PROGRAM="%GAS_7Z:\=/%" ^
  -DNASM_PROGRAM="%GAS_TOOLS:\=/%/nasm.exe" ^
  -DENABLE_CRASH_HANDLER=OFF ^
  -DLINPHONEAPP_VERSION=6.1.0 ^
  -DENABLE_UPDATE_CHECK=OFF ^
  -DENABLE_VPX=%GAS_VPX% ^
  -DENABLE_APP_PACKAGING=%GAS_PACKAGE% ^
  %GAS_SIGNING_FLAG%

if errorlevel 1 (
  echo.
  echo === EL CONFIGURE HA FALLADO ===
  exit /b 1
)
echo.
echo === CONFIGURE CORRECTO ===
echo Para compilar:  compilar.bat
