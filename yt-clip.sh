#!/bin/bash
###############################################################################
# yt-clip-hybrid.sh
# Script híbrido para cortar clips de YouTube o de archivos locales
# - Detecta si es URL o archivo local
# - Tres cuadros Zenity: URL/ruta, inicio, duración
# - Valores por defecto para inicio (00:30) y duración (10s)
# - Abre la carpeta con Nemo (--no-desktop) al terminar, con el fichero 
#   generado marcado
###############################################################################

OUTPUT_DIR="$HOME/Vídeos"
mkdir -p "$OUTPUT_DIR"

# Valores por defecto
DEFAULT_START="00:30"
DEFAULT_DURATION="10"

##########################
# 1️⃣ Pregunta URL o archivo local
##########################
INPUT=$(zenity --entry \
  --title="Descargar/Recortar clip" \
  --text="Introduce la URL de YouTube o la ruta de un archivo local:" \
  --width=600)
[ -z "$INPUT" ] && exit 1

##########################
# 2️⃣ Pregunta tiempo de inicio
##########################
START=$(zenity --entry \
  --title="Tiempo de inicio" \
  --text="Segundo de inicio (HH:MM:SS):" \
  --entry-text="$DEFAULT_START" \
  --width=300)
[ -z "$START" ] && exit 1

##########################
# 3️⃣ Pregunta duración
##########################
DURATION=$(zenity --entry \
  --title="Duración" \
  --text="Duración en segundos:" \
  --entry-text="$DEFAULT_DURATION" \
  --width=300)
[ -z "$DURATION" ] && exit 1

###############################################################################
# Funciones para conversiones de tiempo
###############################################################################
hms_to_sec() {
  IFS=: read -r h m s <<< "$1"
  if [ -z "$s" ]; then
    s=$m
    m=$h
    h=0
  fi
  echo $((10#$h*3600 + 10#$m*60 + 10#$s))
}

sec_to_hms() {
  printf "%02d:%02d:%02d" $(( $1 / 3600 )) $(( ($1 % 3600) / 60 )) $(( $1 % 60 ))
}

START_SEC=$(hms_to_sec "$START")
END_SEC=$((START_SEC + DURATION))
START_HMS=$(sec_to_hms $START_SEC)
END_HMS=$(sec_to_hms $END_SEC)

###############################################################################
# Detectar si es URL o archivo local
###############################################################################
if [[ "$INPUT" =~ ^https?:// ]]; then
    # Es URL: usar yt-dlp
    OUTPUT_FILE=$(yt-dlp \
      --download-sections "*$START_HMS-$END_HMS" \
      -f "bv*[ext=mp4]+ba[ext=m4a]/mp4" \
      -o "$OUTPUT_DIR/%(title)s_%(section_start)s.%(ext)s" \
      --print after_move:filepath \
      "$INPUT")
else
    # Es archivo local
    if [ ! -f "$INPUT" ]; then
        zenity --error --text="Archivo local no encontrado: $INPUT"
        exit 1
    fi
    BASENAME=$(basename "$INPUT")
    EXT="${BASENAME##*.}"
    FILENAME="${BASENAME%.*}_clip.${EXT}"
    OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"
    
    # Cortar con ffmpeg (modo rápido: copy)
    ffmpeg -ss "$START_HMS" -i "$INPUT" -t "$DURATION" -c copy "$OUTPUT_FILE"
fi

# Comprobar si existe el archivo final
[ ! -f "$OUTPUT_FILE" ] && { zenity --error --text="Error creando el clip"; exit 1; }

###############################################################################
# Mensaje final
###############################################################################
FILENAME=$(basename "$OUTPUT_FILE")
zenity --question \
  --title="Clip creado" \
  --text="Archivo creado:\n\n<b>$FILENAME</b>\n\n¿Abrir carpeta?" \
  --ok-label="Abrir carpeta" \
  --cancel-label="Cerrar"

if [ $? -eq 0 ]; then
    nemo --no-desktop "$OUTPUT_FILE"
fi

echo "Archivo final: $OUTPUT_FILE"
