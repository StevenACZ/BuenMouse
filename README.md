# BuenMouse 🖱️

<div align="center">

**Convierte tu mouse en una herramienta de productividad en macOS**

[![macOS](https://img.shields.io/badge/macOS-15.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

*Gestos del trackpad — pero para tu mouse.*

[📥 Descargar](#instalación) · [✨ Características](#características) · [🐞 Reportar bug](https://github.com/StevenACZ/BuenMouse/issues)

</div>

---

## 🎯 ¿Qué es BuenMouse?

BuenMouse es una app menubar gratuita y de código abierto para macOS que le añade a tu mouse los gestos del trackpad que extrañas: abrir **Mission Control**, **cambiar entre espacios**, **hacer zoom**, e **invertir el scroll** — todo con el botón medio (scroll wheel).

Sin Dock icon, sin telemetría, sin ruido. Vive en la barra de menú.

---

## ✨ Características

| Gesto | Acción |
|---|---|
| 🖱️ **Click del botón medio** | Abre Mission Control |
| 🖱️ **Click medio + arrastrar horizontal** | Cambia entre espacios (Spaces) |
| 🔄 **Invert Drag Direction** | Arrastrar derecha → space izquierda y viceversa |
| 📏 **Drag Sensitivity** | Ajusta los px necesarios para cambiar de space (50–250) |
| 🔍 **⌃ Control + Scroll** | Zoom in / out (como pellizcar en el trackpad) |
| ⬆️⬇️ **Invert Scroll Direction** | Scroll natural (estilo trackpad) para tu mouse |

Cada gesto se puede activar o desactivar independientemente desde la ventana principal — con previews animados que muestran exactamente cómo funcionan.

---

## 📥 Instalación

### Descargar el DMG

1. Ve a [Releases](https://github.com/StevenACZ/BuenMouse/releases) y descarga el `.dmg` más reciente
2. Abre el `.dmg` y arrastra **BuenMouse.app** a tu carpeta `Aplicaciones`
3. Abre BuenMouse desde Aplicaciones
4. macOS te pedirá permisos de **Accesibilidad** — actívalos para que los gestos funcionen

### Otorgar permisos de Accesibilidad

BuenMouse necesita permisos de accesibilidad para detectar los clicks y scrolls del mouse. La primera vez que la abras:

1. Abre **Ajustes del Sistema** → **Privacidad y Seguridad** → **Accesibilidad**
2. Haz clic en **+** y agrega **BuenMouse**
3. Activa el toggle al lado del nombre

Ya está — el ícono del cursor aparece en tu barra de menú.

---

## 🎮 Cómo se usa

Después de instalar, haz clic en el ícono de BuenMouse en la barra de menú. Se abre un panel con el estado de la app y una cuadrícula visual de los 4 gestos — un click en cada tarjeta lo activa o desactiva al instante, y el switch de arriba pausa todos los gestos sin cerrar la app.

Desde el panel puedes también:

- **Settings** — ventana con el carrusel animado de gestos, distancia de arrastre, **Launch at Login**, **idioma de la app (English / Español)** y **Reset to Defaults**
- **About BuenMouse** — versión y links del proyecto
- **Quit BuenMouse** — cierra la app

La apariencia sigue automáticamente el tema del sistema (claro / oscuro).

---

## 🛡️ Privacidad

- ❌ **Cero telemetría** — no se envía nada a ningún servidor
- 💻 **Todo es local** — los gestos se procesan en tu Mac
- 🔓 **Código abierto** — puedes auditar exactamente qué hace
- 🔐 **Permisos mínimos** — solo Accesibilidad y Apple Events (para abrir Mission Control)

---

## 🏗️ Para desarrolladores

### Compilar desde el código

```bash
git clone https://github.com/StevenACZ/BuenMouse.git
cd BuenMouse
open BuenMouse.xcodeproj
```

O desde terminal:

```bash
make ci-check
```

Para iterar localmente en tu Mac:

```bash
make install-dev
```

`make install-dev` compila la app Release firmada localmente, la reinstala en
`/Applications/BuenMouse.app` y la relanza sin resetear los permisos de macOS
mientras `Signing.xcconfig` mantenga la misma identidad Apple Development.

### Requisitos

- macOS 15.0+ (Sequoia o más reciente)
- Xcode 16.0+
- Swift 5.0+

### Stack técnico

- **UI**: SwiftUI + AppKit (híbrido)
- **Detección de eventos**: CGEventTap
- **Persistencia**: UserDefaults
- **Launch at login**: ServiceManagement (`SMAppService`)
- **Acciones de sistema**: AppleScript (para Mission Control / Spaces)

---

## 🤝 Contribuir

¿Encontraste un bug o tienes una idea?

1. Abre un [issue](https://github.com/StevenACZ/BuenMouse/issues) describiendo lo que viste o quisieras ver
2. O haz fork, branch (`feature/tu-feature`), y abre un Pull Request

Cada PR debe pasar el build local antes de mergearse.

---

## 📄 Licencia

[MIT](LICENSE) — úsalo, modifícalo, distribúyelo libremente.

---

<div align="center">

**Hecho con ❤️ por [Steven Coaila Zaa](https://github.com/StevenACZ)**

¿Te gustó BuenMouse? Dale una ⭐ al repo o [compártelo](https://github.com/StevenACZ/BuenMouse).

</div>
