# RecortarVideo

**RecortarVideo** es un script Bash con interfaz gráfica (Zenity) para crear clips a partir de archivos locales o de URL compatibles con `yt-dlp`. Está pensado para utilizarse desde el menú contextual de **Nemo**, aunque también puede ejecutarse desde una terminal.

**Versión documentada:** `1.3.0` (26-10-2026)  
**Script:** `yt-clip-v1.3.0.sh` (puedes instalarlo como `yt-clip.sh`)  
**Entorno:** RebornOS / Arch Linux, Nemo y escritorio con soporte para Zenity.

## Características

- Selección inicial entre **Archivo local** y **URL de YouTube**.
- Selector gráfico de archivos locales; propone la última carpeta recordada y, cuando Nemo lo proporciona, el archivo seleccionado.
- Para URL, propone automáticamente una dirección `http://` o `https://` copiada al portapapeles, si hay una herramienta compatible disponible.
- Recuerda la carpeta del último archivo local seleccionado y la usa como **destino de los clips** (también para URL).
- Inicio predeterminado `00:30` y duración predeterminada `10` segundos, ambos editables.
- Inicio en `MM:SS`, `HH:MM:SS` o segundos enteros; duración en segundos enteros positivos.
- Archivos locales: corte mediante `ffmpeg -c copy`, sin recodificación.
- URL: descarga del intervalo indicado mediante `yt-dlp --download-sections`.
- Al terminar, muestra el nombre y la carpeta del resultado y permite abrir esa carpeta en Nemo.
- Opciones de consola `--help` y `--version`.

> **Importante:** el script no guarda siempre en `~/Videos`. La carpeta de salida depende de la última carpeta recordada o, si no existe una válida, de la carpeta que pueda obtener de Nemo, del directorio de trabajo o de `$HOME`.

## Requisitos

Instala las dependencias principales en RebornOS / Arch Linux:

```bash
sudo pacman -S bash zenity ffmpeg yt-dlp nemo python
```

Para sugerir URL desde el portapapeles, instala las herramientas adecuadas a tu sesión:

```bash
# Wayland
sudo pacman -S wl-clipboard

# X11
sudo pacman -S xclip
```

También se admite `xsel` como alternativa a `xclip`. Las herramientas de portapapeles son opcionales: sin ellas puedes escribir o pegar manualmente la URL.

`yt-dlp` y `ffmpeg` deben estar disponibles en el `PATH`. Algunas descargas de servicios externos pueden requerir opciones adicionales de `yt-dlp` o dejar de funcionar por cambios del proveedor.

## Instalación

### Opción A: menú Scripts de Nemo

1. Copia el archivo Bash a la carpeta de scripts del usuario:

   ```bash
   mkdir -p ~/.local/share/nemo/scripts
   cp yt-clip-v1.3.0.sh ~/.local/share/nemo/scripts/yt-clip.sh
   chmod +x ~/.local/share/nemo/scripts/yt-clip.sh
   ```

2. Abre Nemo, haz clic derecho y busca **Scripts > yt-clip.sh**.

### Opción B: acción personalizada de Nemo

Puedes utilizar una acción `.nemo_action` para mostrar el script directamente en el menú contextual.

1. Guarda el script, por ejemplo, en `~/.local/bin/yt-clip.sh`:

   ```bash
   mkdir -p ~/.local/bin ~/.local/share/nemo/actions
   cp yt-clip-v1.3.0.sh ~/.local/bin/yt-clip.sh
   chmod +x ~/.local/bin/yt-clip.sh
   ```

2. Crea `~/.local/share/nemo/actions/recortar-video.nemo_action` con este ejemplo:

   ```ini
   [Nemo Action]
   Name=Recortar vídeo...
   Comment=Crear un clip desde archivo local o URL
   Exec=/home/TU_USUARIO/.local/bin/yt-clip.sh
   Selection=any
   Extensions=any;
   ```

   **Sustituye `TU_USUARIO` por tu nombre de usuario real.** La ruta de `Exec` debe ser absoluta y apuntar a un script ejecutable. Si ya tienes una acción configurada, puedes conservarla y actualizar únicamente la ruta del script cuando sea necesario.

3. Para recargar Nemo:

   ```bash
   nemo -q
   nemo &
   ```

> **Nota:** el comportamiento exacto del menú depende de la configuración de Nemo y de cómo invoque la acción. La última carpeta recordada evita depender exclusivamente de que Nemo transmita su carpeta actual.

## Uso

1. Ejecuta el script desde Nemo o con `~/.local/bin/yt-clip.sh`.
2. Elige **Archivo local** o **URL de YouTube**.
   - **Archivo local:** navega hasta el vídeo. El script recuerda su carpeta y guarda allí el clip.
   - **URL:** acepta, edita o escribe la dirección sugerida desde el portapapeles. El clip se guardará en la última carpeta recordada.
3. Indica el **inicio** (por defecto `00:30`).
4. Indica la **duración en segundos** (por defecto `10`).
5. Espera a que termine la operación y, si quieres, pulsa **Mostrar archivo** para abrir la carpeta de salida en Nemo.

Ejemplo: inicio `01:20` y duración `15` crea un clip del segundo 80 al 95.

### Consulta de ayuda y versión

```bash
~/.local/bin/yt-clip.sh --version
~/.local/bin/yt-clip.sh --help
```

## Carpeta recordada y salida

El script guarda la ruta de la última carpeta local seleccionada en un archivo oculto situado **junto al propio script**:

```text
.yt-clip-ultima-carpeta
```

Por ejemplo, si el script está en `~/.local/bin/yt-clip.sh`, su estado estará en `~/.local/bin/.yt-clip-ultima-carpeta`.

- Al seleccionar otro vídeo local, la ruta se actualiza.
- Al introducir una URL, se conserva la ruta anterior.
- Si la ruta recordada deja de existir o no es escribible, se intenta usar la carpeta actual proporcionada por Nemo, luego el directorio de trabajo y finalmente `$HOME`.
- La carpeta que contiene el script debe permitir escritura para conservar la preferencia.
- Para **restablecer** la carpeta recordada, cierra el script y elimina ese archivo oculto; se creará de nuevo al elegir otro vídeo local.

## Nombres de salida

- **Archivo local:** se genera un nombre como `video_clip.mp4`, conservando normalmente la extensión original.
- **URL:** `yt-dlp` construye el nombre a partir del título, el inicio de la sección y la extensión disponible.
- El script **no sobrescribe** un clip local ya existente con el mismo nombre: muestra un aviso. Para repetir el corte, cambia el nombre del clip existente o muévelo.

## Limitaciones conocidas

- Los cortes locales usan `ffmpeg -c copy`: son rápidos y no recodifican, pero el punto de inicio puede no ser exacto por la posición de los fotogramas clave.
- El selector gráfico recuerda la carpeta del último **archivo local**; no hay un selector independiente de carpeta de destino para URL.
- La sugerencia desde portapapeles solo se aplica si el contenido es una URL completa que empieza por `http://` o `https://`.
- Abrir la carpeta en Nemo no implica necesariamente que el archivo quede seleccionado.
- La compatibilidad con URL depende de los sitios y formatos admitidos por `yt-dlp`.

## Solución de problemas

| Problema | Comprobación |
|---|---|
| No aparece en Nemo | Comprueba la ubicación del script o `.nemo_action`, los permisos de ejecución y reinicia Nemo. |
| El selector comienza en una carpeta inesperada | Comprueba el contenido de `.yt-clip-ultima-carpeta` junto al script y que la carpeta exista. |
| No recuerda la carpeta | Verifica que el directorio donde está el script permite escribir. |
| La URL no aparece automáticamente | Comprueba que tienes `wl-paste` (Wayland) o `xclip`/`xsel` (X11) y que el portapapeles contiene una URL. |
| No se crea el clip | Ejecuta el script desde una terminal para ver errores; comprueba `ffmpeg`, `yt-dlp`, conectividad y permisos de escritura. |
| El corte empieza ligeramente antes o después | Es una limitación posible de `ffmpeg -c copy` sin recodificación. |

## Historial de versiones

Las versiones anteriores a `1.3.0` reflejan la evolución del proyecto durante las iteraciones de desarrollo; no implican que existan etiquetas o versiones publicadas en Git.

| Versión | Cambios |
|---|---|
| 1.0.0 | Recorte desde URL o archivo local, tiempos con Zenity y apertura en Nemo. |
| 1.1.0 | Selector gráfico de archivos e intento de utilizar la carpeta de Nemo como destino. |
| 1.2.0 | Memoria persistente de la última carpeta seleccionada y uso como destino. |
| **1.3.0** | Sugerencia de URL desde portapapeles, documentación interna y opciones `--help` y `--version`. |

## Próximas mejoras posibles

- Selector gráfico opcional para elegir la carpeta de destino de una URL.
- Ajuste de corte preciso mediante recodificación opcional.
- Barra de progreso y mensajes de error más detallados.
- Configuración de inicio y duración predeterminados desde un archivo externo.

## Licencia

**Pendiente de definir.** No se presupone ninguna licencia de distribución hasta que el propietario del proyecto la elija.
