const express = require("express");
const { spawn, execFileSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");

const app = express();
const PORT = 3000;

const DOWNLOAD_FOLDER = path.join(__dirname, "Downloads");
const YT_DLP_PATH = path.join(__dirname, "yt-dlp.exe");

// Crée le dossier de téléchargement s'il n'existe pas
if (!fs.existsSync(DOWNLOAD_FOLDER)) {
  fs.mkdirSync(DOWNLOAD_FOLDER, { recursive: true });
}

// Met à jour yt-dlp au démarrage du serveur
function updateYtDlp() {
  const tempPath = YT_DLP_PATH.replace(".exe", "-new.exe");

  // Si un nouveau binaire a été téléchargé, on remplace l'ancien
  if (fs.existsSync(tempPath)) {
    try {
      if (fs.existsSync(YT_DLP_PATH)) fs.unlinkSync(YT_DLP_PATH);
      fs.renameSync(tempPath, YT_DLP_PATH);
      console.log("yt-dlp mis a jour depuis le fichier telecharge.");
      return;
    } catch {
      console.log("Impossible de remplacer yt-dlp (fichier verrouille ?).");
    }
  }

  if (!fs.existsSync(YT_DLP_PATH)) return;

  console.log("Mise a jour de yt-dlp...");
  try {
    execFileSync(YT_DLP_PATH, ["-U"], { stdio: "inherit", timeout: 60000 });
    console.log("yt-dlp est a jour.");
  } catch {
    console.log("Mise a jour via -U echouee, telechargement depuis GitHub...");
    try {
      execFileSync("powershell", [
        "-Command",
        `Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile '${tempPath}' -UseBasicParsing`,
      ], { stdio: "inherit", timeout: 120000 });
      // On ne peut pas remplacer pendant l'exécution, on le fera au prochain démarrage
      console.log("Nouvelle version telechargee. Elle sera appliquee au prochain demarrage.");
    } catch {
      console.log("Impossible de mettre a jour yt-dlp (continuer quand meme).");
    }
  }
}
updateYtDlp();

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

// Vérifie que yt-dlp.exe existe
app.get("/api/check", (req, res) => {
  const ytDlpExists = fs.existsSync(YT_DLP_PATH);
  res.json({ ytDlpExists, downloadFolder: DOWNLOAD_FOLDER });
});

// Liste les fichiers téléchargés
app.get("/api/files", (req, res) => {
  try {
    const files = fs.readdirSync(DOWNLOAD_FOLDER).map((name) => {
      const filePath = path.join(DOWNLOAD_FOLDER, name);
      const stats = fs.statSync(filePath);
      return {
        name,
        size: stats.size,
        date: stats.mtime,
      };
    });
    files.sort((a, b) => new Date(b.date) - new Date(a.date));
    res.json(files);
  } catch {
    res.json([]);
  }
});

// Ouvre le dossier de téléchargement dans l'explorateur
app.post("/api/open-folder", (req, res) => {
  spawn("explorer", [DOWNLOAD_FOLDER]);
  res.json({ ok: true });
});

// Téléchargement avec Server-Sent Events pour le suivi en temps réel
app.get("/api/download", (req, res) => {
  const { url, type } = req.query;

  if (!url || !type) {
    res.status(400).json({ error: "URL et type requis" });
    return;
  }

  if (!["video", "audio"].includes(type)) {
    res.status(400).json({ error: "Type invalide (video ou audio)" });
    return;
  }

  if (!fs.existsSync(YT_DLP_PATH)) {
    res.status(500).json({ error: "yt-dlp.exe introuvable" });
    return;
  }

  // Configuration SSE
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  const sendEvent = (event, data) => {
    res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
  };

  // Construction des arguments yt-dlp
  const args = [];

  if (type === "video") {
    args.push(
      "-f", "bv*+ba/b",
      "--merge-output-format", "mp4",
      "--paths", `temp:${os.tmpdir()}`,
      "--restrict-filenames",
      "--newline",
      "-o", path.join(DOWNLOAD_FOLDER, "%(title)s.%(ext)s"),
      url
    );
  } else {
    args.push(
      "-f", "bestaudio",
      "--extract-audio",
      "--audio-format", "mp3",
      "--restrict-filenames",
      "--newline",
      "-o", path.join(DOWNLOAD_FOLDER, "%(title)s.%(ext)s"),
      url
    );
  }

  // Ajoute ffmpeg si disponible au chemin connu
  const ffmpegPath = "C:\\ffmpeg\\bin\\ffmpeg.exe";
  if (fs.existsSync(ffmpegPath)) {
    args.push("--ffmpeg-location", ffmpegPath);
  }

  sendEvent("log", { message: `Démarrage du téléchargement (${type})...` });
  sendEvent("log", { message: `URL: ${url}` });

  const proc = spawn(YT_DLP_PATH, args);
  let lastProgress = "";

  proc.stdout.on("data", (data) => {
    const lines = data.toString().split("\n").filter(Boolean);
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      // Détecte les lignes de progression
      const progressMatch = trimmed.match(/\[download\]\s+([\d.]+)%/);
      if (progressMatch) {
        const percent = progressMatch[1];
        if (percent !== lastProgress) {
          lastProgress = percent;
          sendEvent("progress", { percent: parseFloat(percent) });
        }
      }

      sendEvent("log", { message: trimmed });
    }
  });

  proc.stderr.on("data", (data) => {
    const lines = data.toString().split("\n").filter(Boolean);
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed) {
        sendEvent("log", { message: `⚠ ${trimmed}` });
      }
    }
  });

  proc.on("close", (code) => {
    if (code === 0) {
      sendEvent("done", { success: true, message: "Téléchargement terminé !" });
    } else {
      sendEvent("done", {
        success: false,
        message: `Erreur lors du téléchargement (code ${code})`,
      });
    }
    res.end();
  });

  proc.on("error", (err) => {
    sendEvent("done", {
      success: false,
      message: `Erreur: ${err.message}`,
    });
    res.end();
  });

  // Gère la déconnexion du client
  req.on("close", () => {
    proc.kill();
  });
});

app.listen(PORT, () => {
  console.log(`Serveur demarré sur http://localhost:${PORT}`);
});
