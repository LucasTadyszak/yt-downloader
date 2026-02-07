param(
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [Parameter(Mandatory = $true)]
    [ValidateSet("video", "audio")]
    [string]$Type
)

$DowloaderFolder = "C:\Users\Jacques Lenovo\Desktop\yt-downloader\Videos_YouTube"
$FFmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"  # Remplace ce chemin par celui où tu as installé FFmpeg

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

Write-Host "`nVerification des mises a jour de yt-dlp..." -ForegroundColor DarkGray
& $ytDlpPath -U | Out-Null

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
        & $ytDlpPath -f "bv*+ba/b" --restrict-filenames -o "$DowloaderFolder\mp3_$cleanedTitle.%(ext)s" $Url --ffmpeg-location $FFmpegPath
    }
    "audio" {
        & $ytDlpPath -f bestaudio --extract-audio --audio-format mp3 --restrict-filenames -o "$DowloaderFolder\mp4_$cleanedTitle.%(ext)s" $Url --ffmpeg-location $FFmpegPath
    }
}

Write-Host "`nTelechargement termine !" -ForegroundColor Green
Write-Host "Les fichiers sont enregistres dans : $DowloaderFolder" -ForegroundColor Cyan
