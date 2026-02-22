# RecortarVideo
Recortar un vídeo local o vía http

Script híbrido en Bash para **crear clips de vídeo** a partir de:

- 🌐 **URLs** (YouTube u otros servicios compatibles con `yt-dlp`)
- 📁 **Archivos de vídeo locales**

Todo mediante **ventanas gráficas (Zenity)** y con apertura automática del resultado en **Nemo**.

---

## ✨ Características

- Tres diálogos gráficos independientes:
  1. URL o ruta de archivo local
  2. Tiempo de inicio
  3. Duración del clip
- Valores por defecto para inicio (`00:30`) y duración (`10` segundos)
- Detección automática:
  - URL → usa `yt-dlp`
  - Archivo local → usa `ffmpeg`
- Genera un clip en `~/Videos`
- Abre Nemo mostrando el archivo generado
- Compatible con Cinnamon / RebornOS / Arch Linux

---

## 📦 Requisitos

Asegúrate de tener instalados los siguientes paquetes:

### 1️⃣ yt-dlp
```bash
sudo pacman -S yt-dlp
```

---

### 2️⃣ ffmpeg
```bash
sudo pacman -S ffmpeg
```

---

### 3️⃣ zenity
```bash
sudo pacman -S zenity
```

---

### 4️⃣ nemo (gestor de archivos)
```bash
sudo pacman -S nemo
```

---

📁 Instalación

Guarda el script como, por ejemplo:

```bash
~/.local/bin/yt-clip-hybrid.sh
```

Dale permisos de ejecución:

```bash
chmod +x ~/.local/bin/yt-clip-hybrid.sh
```

(Opcional) Asegúrate de que ~/.local/bin está en tu PATH:
```bash
echo $PATH
```

---

## 🖱️ Integración con Nemo (menú contextual)

Es posible ejecutar el script directamente desde **Nemo** usando una **acción personalizada**, que aparecerá al hacer **clic derecho**.

---

### 📁 Ubicación del archivo de acción

Nemo carga las acciones desde el siguiente directorio del usuario:

```text
~/.local/share/nemo/actions/
```
⚠️ Importante
Asegúrate de que la ruta en Exec= apunta exactamente al script y que este es ejecutable:

Una vez copiado el fichero de acción recargar nemo 

```bash
nemo -q && nemo
```
