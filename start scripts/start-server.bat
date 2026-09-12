@echo off
setlocal enabledelayedexpansion

REM ==================================================
REM  Valheim Dedicated Server - Docker Launcher
REM  Uses ghcr.io/community-valheim-tools/valheim-server
REM  (drop-in compatible with ghcr.io/lloesche/valheim-server)
REM ==================================================

REM ---- Edit these before running ----
set "SERVER_NAME=My Server"
set "WORLD_NAME=Midgard"
set "SERVER_PASS=changeme123"
set "SERVER_PUBLIC=true"
set "CONTAINER_NAME=valheim-server"
set "IMAGE=ghcr.io/community-valheim-tools/valheim-server"
REM Avoid !, ^, %%, and " characters in SERVER_PASS - batch parses these specially.
REM ------------------------------------

set "BASE_DIR=%USERPROFILE%\valheim-server"
set "CONFIG_DIR=%BASE_DIR%\config"
set "DATA_DIR=%BASE_DIR%\data"

echo.
echo === Valheim Dedicated Server Launcher ===
echo.

REM --- Check Docker is installed and running ---
where docker >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker was not found on PATH. Install Docker Desktop first:
    echo         https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is installed but not running. Start Docker Desktop and try again.
    pause
    exit /b 1
)

REM --- Validate password length (Valheim requires 5+ characters) ---
set "PASS_LEN=0"
for /l %%i in (0,1,50) do (
    if "!SERVER_PASS:~%%i,1!" neq "" set /a PASS_LEN=%%i+1
)
if !PASS_LEN! LSS 5 (
    echo [ERROR] SERVER_PASS must be at least 5 characters long. Edit this script and try again.
    pause
    exit /b 1
)

REM --- Create persistent directories ---
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
echo Config directory: %CONFIG_DIR%
echo Data directory:   %DATA_DIR%
echo.

REM --- Remove any previous container with the same name ---
docker inspect %CONTAINER_NAME% >nul 2>&1
if not errorlevel 1 (
    echo Found an existing container named "%CONTAINER_NAME%".
    set /p "REPLACE=Remove it and start fresh? (y/n): "
    if /i "!REPLACE!"=="y" (
        docker rm -f %CONTAINER_NAME% >nul
        echo Removed existing container.
    ) else (
        echo Aborting. Remove or rename the existing container manually and re-run.
        pause
        exit /b 1
    )
)

REM --- Launch the server ---
echo Starting Valheim server "%SERVER_NAME%" ...
docker run -d ^
    --name %CONTAINER_NAME% ^
    --cap-add=sys_nice ^
    --stop-timeout 120 ^
    --restart unless-stopped ^
    -p 2456-2457:2456-2457/udp ^
    -v "%CONFIG_DIR%:/config" ^
    -v "%DATA_DIR%:/opt/valheim" ^
    -e SERVER_NAME="%SERVER_NAME%" ^
    -e WORLD_NAME="%WORLD_NAME%" ^
    -e SERVER_PASS="%SERVER_PASS%" ^
    -e SERVER_PUBLIC="%SERVER_PUBLIC%" ^
    %IMAGE%

if errorlevel 1 (
    echo [ERROR] Failed to start the container. Check the output above.
    pause
    exit /b 1
)

echo.
echo Server container started. First boot downloads ~1GB from Steam,
echo so it may take a few minutes before the server is joinable.
echo.
echo View logs with:   docker logs -f %CONTAINER_NAME%
echo Stop the server:  docker stop %CONTAINER_NAME%
echo Remove entirely:  docker rm -f %CONTAINER_NAME%
echo.
pause