# CreamEngine

**CreamEngine** es un proyecto de motor/engine de juego de ritmo desarrollado en **Haxe**, construido sobre **HaxeFlixel**, **OpenFL** y **Lime**. Su objetivo es ofrecer una base propia para crear y ejecutar un juego al estilo *Friday Night Funkin'*, con sistemas de gameplay, carga de canciones, personajes, escenarios, mods y vibración háptica.

> **Estado:** en desarrollo. La estructura y varios sistemas ya están implementados, pero el gameplay y algunas herramientas todavía están en construcción. No se considera una versión estable.

## Características

- **Gameplay rítmico:** base de juego con notas, strumlines, personajes, puntuación, misses y salud.
- **Sistema de canciones:** carga charts y metadatos JSON, dificultades y velocidad de scroll.
- **Conductor musical:** seguimiento de la posición de la canción, beats, steps, measures y cambios de BPM; admite cambios inmediatos y transiciones de tempo.
- **Personajes y escenarios:** carga de datos JSON, animaciones, offsets, posiciones y propiedades de escenario.
- **Soporte inicial para mods:** detección de carpetas de mods con `mod.json` y resolución de assets sobrescritos.
- **Hápticos:** reproducción de vibración en dispositivos móviles y mandos compatibles, además de charts hápticos en JSON.
- **Haptic Chart Editor:** herramienta HTML local para crear, editar, previsualizar e importar/exportar patrones de vibración.
- **Objetivos multiplataforma:** configuración de proyecto para escritorio y Android; algunas funciones dependen de la plataforma y de sus extensiones.

## Tecnologías

| Tecnología | Uso |
| --- | --- |
| Haxe | Lenguaje principal |
| HaxeFlixel | Framework de juego |
| OpenFL | Capa multimedia y de aplicación |
| Lime | Compilación y targets |
| FlxAnimate | Animaciones |
| extension-haptics | Vibración en Android/iOS |
| openfl-ffmpeg | Decodificación de vídeo en Android |

## Requisitos

Para compilar el proyecto necesitas:

- [Haxe](https://haxe.org/)
- [HaxeFlixel](https://haxeflixel.com/)
- [Lime](https://lime.openfl.org/)
- Android Studio y Android SDK/NDK si vas a compilar para Android.

Instala las dependencias Haxe utilizadas por el proyecto:

```bash
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib install flixel-addons
haxelib install flxanimate
haxelib install openfl-ffmpeg
haxelib install extension-haptics
```

Las dos últimas dependencias se usan en el target Android/móvil según las condiciones de `project.xml`. Después, configura Lime:

```bash
haxelib run lime setup
```

## Obtener el código

```bash
git clone https://github.com/Krimio24/CreamEngine.git
cd CreamEngine
```

## Compilar y ejecutar

La configuración del proyecto está en `project.xml`. El tamaño inicial de la ventana es **1280 × 720**.

Para probar en Windows:

```bash
lime test windows
```

Para compilar Android en modo debug:

```bash
lime build android -debug
```

Para una compilación Android release:

```bash
lime build android -release
```

También se incluyen los scripts `build-android-debug.bat` y `build-android.bat` para Windows. Estos esperan una instalación local de Android Studio, Java y Android NDK; revisa las rutas configuradas en los scripts y tu entorno antes de ejecutarlos.

## Estructura del proyecto

```text
CreamEngine/
├── Source/
│   ├── Main.hx
│   └── funkin/
│       ├── Conductor.hx
│       ├── modding/
│       ├── play/
│       │   ├── characters/
│       │   ├── notes/
│       │   ├── song/
│       │   └── stage/
│       ├── sprites/
│       ├── ui/
│       └── util/
├── assets/
│   ├── gameplay/
│   │   ├── characters/
│   │   ├── dialogue/
│   │   ├── songs/
│   │   └── stages/
│   └── ui/
├── tools/
│   ├── android/
│   └── HapticChartEditor.html
├── project.xml
├── build-android-debug.bat
└── build-android.bat
```

## Charts hápticos

CreamEngine incluye `tools/HapticChartEditor.html`. Ábrelo directamente en un navegador moderno; no requiere instalación ni servidor local.

El editor permite:

- Definir BPM, compases, subdivisiones y compás musical.
- Cargar un archivo de audio o vídeo como referencia temporal.
- Colocar, mover y editar pulsos en una línea de tiempo.
- Configurar duración e intensidad para el motor izquierdo y derecho.
- Importar y exportar charts JSON.
- Probar la vibración con un gamepad compatible y un navegador que admita la API de vibración.

Los charts exportados utilizan eventos con los campos `atMs`, `durationMs`, `left` y `right`. El runtime puede reproducirlos mediante `HapticUtil.playChart()` o `HapticUtil.playChartFromJson()`.

## Mods

El sistema inicial de mods busca carpetas dentro de `mods/`. Cada mod debe incluir un archivo `mod.json` con sus metadatos.

Ejemplo:

```json
{
  "id": "my-mod",
  "name": "My Mod",
  "author": "Author",
  "description": "A custom mod",
  "version": "1.0.0"
}
```

Los assets del mod pueden colocarse dentro de su carpeta `assets/` para que el sistema de resolución de recursos pueda encontrar archivos sobrescritos.

> El soporte de mods todavía es inicial y puede variar según el target. No todas las funciones de un sistema completo de modding están implementadas.

## Créditos y recursos

CreamEngine utiliza HaxeFlixel, OpenFL, Lime y otras herramientas de código abierto. El repositorio también contiene recursos del proyecto **Friday Night Funkin'** y de **The Funkin' Crew**.

Los créditos y los términos de uso de cada recurso pertenecen a sus respectivos autores. Antes de redistribuir builds o assets, revisa las licencias y condiciones aplicables. CreamEngine no implica afiliación oficial con The Funkin' Crew.

## Licencia

No se especifica una licencia para CreamEngine en este README. Consulta los archivos del repositorio y los avisos de cada recurso antes de reutilizar o redistribuir el código y los assets.
