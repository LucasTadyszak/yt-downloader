@echo off
title TELECHARGEUR YOUTUBE
color 0a

echo ============================================
echo           TELECHARGEUR YOUTUBE
echo ============================================
echo.

if not exist telecharger_youtube.ps1 (
  echo Erreur : le fichier telecharger_youtube.ps1 est introuvable.
  pause
  exit /b
)

:MENU
cls
echo Choisis le type de telechargement :
echo.
echo   1. Video (mp4)
echo   2. Audio (mp3)
echo   3. Quitter
echo.
set /p CHOIX=Ton choix (1-3) : 

if "%CHOIX%"=="1" set TYPE=video
if "%CHOIX%"=="2" set TYPE=audio
if "%CHOIX%"=="3" exit /b

if "%TYPE%"=="" (
  cls
  echo Choix invalide ! Choisir un chiffre entre 1 et 3 selon le menu.
  pause
  goto MENU
)

echo.
set /p URL=Colle ici l'URL YouTube : 

if "%URL%"=="" (
  echo Aucune URL entrée !
  pause
  goto MENU
)

echo.
echo ==========================================
echo Telechargement en cours ...
echo ==========================================
echo.

powershell -ExecutionPolicy Bypass -File "telecharger_youtube.ps1" -Url "%URL%" -Type "%TYPE%"

echo.
echo Telechargement termine ! Appuyez sur une touche pour revenir au menu.
pause >nul

goto MENU
