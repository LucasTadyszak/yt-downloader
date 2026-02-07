param(
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [Parameter(Mandatory = $true)]
    [ValidateSet("video", "audio")]
    [string]$Type
)

$DowloaderFolder = Join-Path ([Environment]::GetFolderPath("Desktop")) "yt-downloader\Videos_YouTube"
$FFmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"

# Installe ffmpeg si introuvable
if (!(Test-Path $FFmpegPath)) {
    Write-Host "ffmpeg introuvable. Telechargement automatique..." -ForegroundColor DarkYellow
    try {
        $ffmpegZip = Join-Path $env:TEMP "ffmpeg.zip"
        $ffmpegExtract = Join-Path $env:TEMP "ffmpeg-extract"
        Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile $ffmpegZip -UseBasicParsing
        Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegExtract -Force
        $ffmpegDir = Get-ChildItem $ffmpegExtract -Directory | Select-Object -First 1
        if (!(Test-Path "C:\ffmpeg")) { New-Item -ItemType Directory -Path "C:\ffmpeg" | Out-Null }
        Copy-Item -Path (Join-Path $ffmpegDir.FullName "bin") -Destination "C:\ffmpeg\bin" -Recurse -Force
        Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
        Remove-Item $ffmpegExtract -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "ffmpeg installe avec succes." -ForegroundColor Green
    } catch {
        Write-Host "Impossible d'installer ffmpeg automatiquement: $_" -ForegroundColor Red
        Write-Host "Telecharge-le manuellement depuis https://ffmpeg.org/download.html" -ForegroundColor Yellow
        exit 1
    }
}

# Vérifie si le dossier de téléchargement existe
if (!(Test-Path $DowloaderFolder)) {
    New-Item -ItemType Directory -Path $DowloaderFolder | Out-Null
}

$ytDlpPath = Join-Path $PSScriptRoot "yt-dlp.exe"

# Télécharge yt-dlp si nécessaire
if (!(Test-Path $ytDlpPath)) {
    Write-Host "yt-dlp.exe est introuvable. Telechargement automatique..." -ForegroundColor DarkYellow
    try {
        Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $ytDlpPath -UseBasicParsing
        Write-Host "yt-dlp telecharge avec succès." -ForegroundColor Green
    } catch {
        Write-Host "Impossible de telecharger yt-dlp. Verifie ta connexion Internet." -ForegroundColor Red
        exit 1
    }
}

# Mise a jour de yt-dlp vers la derniere version
Write-Host "`nMise a jour de yt-dlp..." -ForegroundColor DarkYellow
try {
    $updateOutput = & $ytDlpPath -U 2>&1
    $updateText = $updateOutput | Out-String
    if ($updateText -match "up to date|Updated yt-dlp") {
        Write-Host "yt-dlp est a jour." -ForegroundColor Green
    } else {
        Write-Host $updateText -ForegroundColor Gray
    }
} catch {
    Write-Host "Mise a jour via -U echouee, telechargement depuis GitHub..." -ForegroundColor DarkYellow
    try {
        Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $ytDlpPath -UseBasicParsing
        Write-Host "yt-dlp mis a jour avec succes." -ForegroundColor Green
    } catch {
        Write-Host "Impossible de mettre a jour yt-dlp. On continue avec la version actuelle." -ForegroundColor DarkYellow
    }
}

Write-Host "--------------------------------------" -ForegroundColor DarkCyan
Write-Host " URL      : $Url" -ForegroundColor Cyan
Write-Host " Type     : $Type" -ForegroundColor Cyan
Write-Host " Dossier  : $DowloaderFolder" -ForegroundColor Cyan
Write-Host "--------------------------------------" -ForegroundColor DarkCyan

# Remplace les caractères spéciaux dans le titre de la vidéo
$cleanedTitle = (Invoke-Expression '$Url' | Out-String) -replace '[^\w\s-]', '_'
$cleanedTitle = $cleanedTitle -replace '\s+', '_'  # Remplace les espaces par des underscores

# Limite la longueur du titre à 100 caractères pour éviter que le chemin soit trop long
$cleanedTitle = $cleanedTitle.Substring(0, [Math]::Min(100, $cleanedTitle.Length))

# Téléchargement de la vidéo ou de l'audio
switch ($Type) {
    "video" {
        & $ytDlpPath -f "bv*+ba/b" --merge-output-format mp4 --paths "temp:$env:TEMP" --restrict-filenames -o "$DowloaderFolder\mp4_$cleanedTitle.%(ext)s" $Url --ffmpeg-location $FFmpegPath
    }
    "audio" {
        & $ytDlpPath -f bestaudio --extract-audio --audio-format mp3 --restrict-filenames -o "$DowloaderFolder\mp4_$cleanedTitle.%(ext)s" $Url --ffmpeg-location $FFmpegPath
    }
}

Write-Host "`nTelechargement termine !" -ForegroundColor Green
Write-Host "Les fichiers sont enregistres dans : $DowloaderFolder" -ForegroundColor Cyan
