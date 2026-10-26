#!/bin/bash
# =============================================================================
# yt-clip.sh - Recortador grafico de videos para Nemo
# Version: 1.3.0
# Fecha de version: 2026-10-26
# Autor: jrios2006 / asistencia de ChatGPT (adaptaciones)
# Licencia: No especificada
#
# DESCRIPCION
#   Recorta un fragmento de un archivo de video local o de una URL admitida
#   por yt-dlp. Interactua con el usuario mediante ventanas de Zenity.
#
# FUNCIONES
#   - Seleccion grafica de video local o entrada de URL.
#   - Propone automaticamente una URL copiada en el portapapeles.
#   - Abre el selector local en la ultima carpeta recordada.
#   - Guarda los clips en esa misma carpeta; al seleccionar un archivo local,
#     actualiza la carpeta recordada.
#   - Acepta tiempos de inicio MM:SS, HH:MM:SS o segundos enteros.
#   - Recorta archivos locales con ffmpeg (-c copy, sin recodificar).
#   - Descarga secciones de videos con yt-dlp.
#   - Ofrece abrir la carpeta de salida en Nemo al terminar.
#
# DEPENDENCIAS
#   Obligatorias: bash, zenity, python3 (para URI de Nemo), ffmpeg,
#                 yt-dlp, nemo (para abrir carpeta al terminar).
#   Portapapeles: wl-paste (Wayland) o xclip/xsel (X11), opcionales.
#
# USO
#   Desde Nemo: boton derecho > Scripts > yt-clip.sh
#   Desde terminal: ./yt-clip.sh
#                   ./yt-clip.sh --help
#                   ./yt-clip.sh --version
#
# CONFIGURACION
#   DEFAULT_START y DEFAULT_DURATION: valores iniciales de las ventanas.
#   .yt-clip-ultima-carpeta: fichero oculto junto al script, contiene una
#   unica ruta; la carpeta del script debe permitir escritura.
#   Si la ruta recordada no existe, intenta usar Nemo, PWD o HOME.
#
# LIMITACIONES
#   - En archivos locales, -c copy puede desplazar ligeramente el inicio
#     del corte al fotograma clave mas cercano.
#   - Una URL no cambia la carpeta recordada.
#   - No sobrescribe un clip local que ya exista.
#   - El comportamiento de las descargas depende de yt-dlp y ffmpeg.
#
# HISTORIAL (versiones reconstruidas a partir de las iteraciones)
#   1.0.0 - Entrada de URL/ruta, inicio y duracion; corte y apertura con Nemo.
#   1.1.0 - Seleccion grafica de archivo y destino segun carpeta de Nemo.
#   1.2.0 - Persistencia de ultima carpeta y uso como destino.
#   1.3.0 - URL sugerida desde portapapeles; documentacion y --help/--version.
# =============================================================================

SCRIPT_NAME="yt-clip"
SCRIPT_VERSION="1.3.0"

show_help() {
    cat <<'HELP'
yt-clip v1.3.0 - Recorta videos desde Nemo o una terminal.

Uso:
  yt-clip.sh              Abre el asistente grafico.
  yt-clip.sh --version    Muestra la version.
  yt-clip.sh --help       Muestra esta ayuda.

Flujo:
  1. Elige archivo local o URL.
  2. Indica el inicio (MM:SS o HH:MM:SS) y la duracion en segundos.
  3. Se guarda el clip en la ultima carpeta recordada.
  4. Opcionalmente, abre la carpeta de salida en Nemo.

Estado: .yt-clip-ultima-carpeta, junto al script.
Dependencias: zenity, ffmpeg, yt-dlp; Nemo para abrir carpeta;
             wl-paste, xclip o xsel para sugerir URL del portapapeles.
HELP
}

case "${1:-}" in
    --version|-V) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
    --help|-h) show_help; exit 0 ;;
esac


DEFAULT_START="00:30"
DEFAULT_DURATION="10"

# ESTADO: fichero de persistencia de la ultima carpeta seleccionada.
# Recordar la ultima carpeta en un fichero junto al script.
SCRIPT_DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
STATE_FILE="$SCRIPT_DIR/.yt-clip-ultima-carpeta"

# Prioridad: carpeta recordada, carpeta de Nemo, directorio actual, HOME.
OUTPUT_DIR=""
if [[ -f "$STATE_FILE" ]]; then
    IFS= read -r OUTPUT_DIR < "$STATE_FILE"
fi
if [[ ! -d "$OUTPUT_DIR" || ! -w "$OUTPUT_DIR" ]]; then
    if [[ "${NEMO_SCRIPT_CURRENT_URI:-}" == file://* ]]; then
        OUTPUT_DIR=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(urllib.parse.urlparse(sys.argv[1]).path))' "$NEMO_SCRIPT_CURRENT_URI")
    else
        OUTPUT_DIR="$PWD"
    fi
fi
if [[ ! -d "$OUTPUT_DIR" || ! -w "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$HOME"
fi

remember_dir() {
    local directory="$1"
    if [[ -d "$directory" && -w "$directory" ]]; then
        OUTPUT_DIR="$directory"
        # Si el directorio del script no permite escritura, avisar sin impedir el corte.
        if ! printf '%s\n' "$directory" > "$STATE_FILE"; then
            zenity --warning --text="No se pudo recordar la carpeta.\nComprueba los permisos de: $SCRIPT_DIR"
        fi
    fi
}

# Si se invoca desde el menu contextual sobre un archivo, usarlo como entrada.
SELECTED=""
if [[ -n "${NEMO_SCRIPT_SELECTED_FILE_PATHS:-}" ]]; then
    SELECTED="${NEMO_SCRIPT_SELECTED_FILE_PATHS%%$'\n'*}"
fi

# ENTRADA: elegir entre archivo local y URL; se puede cancelar sin error.
CHOICE=$(zenity --list --radiolist \
    --title="Descargar/Recortar clip" \
    --text="¿De dónde procede el vídeo?\nDestino: $OUTPUT_DIR" \
    --column="" --column="Origen" \
    TRUE "Archivo local" FALSE "URL de YouTube" \
    --width=620 --height=270) || exit 0

case "$CHOICE" in
    "Archivo local")
        if [[ -n "$SELECTED" && -f "$SELECTED" ]]; then
            INITIAL_FILE="$SELECTED"
        else
            INITIAL_FILE="$OUTPUT_DIR/"
        fi
        INPUT=$(zenity --file-selection \
            --title="Selecciona el vídeo local" \
            --filename="$INITIAL_FILE" \
            --width=800) || exit 0
        [[ -f "$INPUT" ]] || { zenity --error --text="No se encuentra el archivo seleccionado."; exit 1; }
        remember_dir "$(dirname -- "$INPUT")"
        IS_URL=0
        ;;
    "URL de YouTube")
        # Leer el portapapeles sin modificarlo (Wayland o X11).
        CLIPBOARD_URL=""
        if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-paste >/dev/null 2>&1; then
            CLIPBOARD_URL=$(wl-paste --no-newline 2>/dev/null) || CLIPBOARD_URL=""
        elif command -v xclip >/dev/null 2>&1; then
            CLIPBOARD_URL=$(xclip -selection clipboard -o 2>/dev/null) || CLIPBOARD_URL=""
        elif command -v xsel >/dev/null 2>&1; then
            CLIPBOARD_URL=$(xsel --clipboard --output 2>/dev/null) || CLIPBOARD_URL=""
        fi
        # Solo proponer texto que sea una URL completa, no datos arbitrarios.
        CLIPBOARD_URL="${CLIPBOARD_URL//$'\r'/}"
        CLIPBOARD_URL="${CLIPBOARD_URL%$'\n'}"
        if [[ "$CLIPBOARD_URL" != http://* && "$CLIPBOARD_URL" != https://* || "$CLIPBOARD_URL" == *$'\n'* ]]; then
            CLIPBOARD_URL=""
        fi
        INPUT=$(zenity --entry \
            --entry-text="$CLIPBOARD_URL" \
            --title="URL del vídeo" \
            --text="Introduce la URL de YouTube:" \
            --width=600) || exit 0
        [[ "$INPUT" =~ ^https?:// ]] || { zenity --error --text="Introduce una URL que empiece por http:// o https://"; exit 1; }
        IS_URL=1
        ;;
    *) exit 0 ;;
esac

# TIEMPOS: solicitar y validar los parametros del corte.
START=$(zenity --entry \
    --title="Tiempo de inicio" \
    --text="Inicio del clip (MM:SS o HH:MM:SS):" \
    --entry-text="$DEFAULT_START" --width=350) || exit 0

DURATION=$(zenity --entry \
    --title="Duración" \
    --text="Duración en segundos:" \
    --entry-text="$DEFAULT_DURATION" --width=350) || exit 0

if [[ ! "$DURATION" =~ ^[0-9]+$ ]] || (( 10#$DURATION <= 0 )); then
    zenity --error --text="La duración debe ser un número entero positivo."
    exit 1
fi
DURATION=$((10#$DURATION))

hms_to_sec() {
    local value="$1" h m s
    if [[ "$value" =~ ^([0-9]+):([0-5]?[0-9]):([0-5]?[0-9])$ ]]; then
        h="${BASH_REMATCH[1]}"; m="${BASH_REMATCH[2]}"; s="${BASH_REMATCH[3]}"
    elif [[ "$value" =~ ^([0-9]+):([0-5]?[0-9])$ ]]; then
        h=0; m="${BASH_REMATCH[1]}"; s="${BASH_REMATCH[2]}"
    elif [[ "$value" =~ ^[0-9]+$ ]]; then
        h=0; m=0; s="$value"
    else
        return 1
    fi
    echo $((10#$h * 3600 + 10#$m * 60 + 10#$s))
}

sec_to_hms() {
    printf '%02d:%02d:%02d' "$(( $1 / 3600 ))" "$(( ($1 % 3600) / 60 ))" "$(( $1 % 60 ))"
}

START_SEC=$(hms_to_sec "$START") || { zenity --error --text="Formato de inicio no válido."; exit 1; }
END_SEC=$((START_SEC + DURATION))
START_HMS=$(sec_to_hms "$START_SEC")
END_HMS=$(sec_to_hms "$END_SEC")

# PROCESAMIENTO: yt-dlp para URL, ffmpeg para archivos locales.
if (( IS_URL )); then
    # Guardar la salida normal en un archivo temporal para no confundirla con la ruta final.
    LOG=$(mktemp)
    OUTPUT_FILE=$(yt-dlp \
        --download-sections "*$START_HMS-$END_HMS" \
        -f "bv*[ext=mp4]+ba[ext=m4a]/mp4" \
        -o "$OUTPUT_DIR/%(title)s_%(section_start)s.%(ext)s" \
        --print after_move:filepath \
        "$INPUT" 2>"$LOG")
    STATUS=$?
    if (( STATUS != 0 )); then
        zenity --error --title="Error de yt-dlp" --text="No se pudo descargar el clip.\n\n$(tail -n 8 "$LOG")"
        rm -f "$LOG"
        exit 1
    fi
    rm -f "$LOG"
    OUTPUT_FILE=$(printf '%s\n' "$OUTPUT_FILE" | tail -n 1)
else
    BASENAME=$(basename "$INPUT")
    if [[ "$BASENAME" == *.* ]]; then
        EXT="${BASENAME##*.}"
        NAME="${BASENAME%.*}"
        OUTPUT_FILE="$OUTPUT_DIR/${NAME}_clip.${EXT}"
    else
        OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}_clip.mp4"
    fi
    # Evitar sobreescribir el clip existente o el propio fichero de origen.
    if [[ -e "$OUTPUT_FILE" ]]; then
        zenity --error --text="Ya existe el archivo de destino:\n$OUTPUT_FILE\n\nCámbiale el nombre antes de repetir la operación."
        exit 1
    fi
    LOG=$(mktemp)
    if ! ffmpeg -n -ss "$START_HMS" -i "$INPUT" -t "$DURATION" -c copy "$OUTPUT_FILE" >"$LOG" 2>&1; then
        zenity --error --title="Error de ffmpeg" --text="No se pudo crear el clip.\n\n$(tail -n 8 "$LOG")"
        rm -f "$LOG"
        exit 1
    fi
    rm -f "$LOG"
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
    zenity --error --text="Error creando el clip."
    exit 1
fi

# RESULTADO: confirmar la salida y ofrecer abrir su carpeta en Nemo.
FILENAME=$(basename "$OUTPUT_FILE")
if zenity --question \
    --title="Clip creado" \
    --text="Archivo creado:\n\n<b>$FILENAME</b>\n\nGuardado en:\n$OUTPUT_DIR\n\n¿Mostrar archivo en Nemo?" \
    --ok-label="Mostrar archivo" --cancel-label="Cerrar"; then
    nemo --no-desktop "$OUTPUT_DIR" >/dev/null 2>&1 &
fi

printf 'Archivo final: %s\n' "$OUTPUT_FILE"
