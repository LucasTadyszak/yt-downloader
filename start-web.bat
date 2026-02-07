@echo off
title TELECHARGEUR YOUTUBE - Web
color 0a

echo ============================================
echo       TELECHARGEUR YOUTUBE - Web
echo ============================================
echo.

:: Vérifie que Node.js est installé
where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Erreur : Node.js n'est pas installe.
    echo Telecharge-le ici : https://nodejs.org/
    echo.
    pause
    exit /b
)

:: Vérifie que yt-dlp.exe existe
if not exist "%~dp0yt-dlp.exe" (
    echo Attention : yt-dlp.exe est introuvable.
    echo Le telechargement ne fonctionnera pas sans ce fichier.
    echo.
)

:: Installe les dépendances si nécessaire
if not exist "%~dp0node_modules" (
    echo Installation des dependances...
    echo.
    cd /d "%~dp0"
    call npm install
    echo.
)

echo Demarrage du serveur...
echo.

:: Lance le serveur et ouvre le navigateur après un délai
cd /d "%~dp0"
start "" http://localhost:3000
node server.js
