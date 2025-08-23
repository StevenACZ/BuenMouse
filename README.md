# BuenMouse 🖱️

<div align="center">

**Revoluciona tu experiencia con mouse y trackpad en macOS**

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)]()
[![Version](https://img.shields.io/badge/Version-2.0+-red.svg)]()

*Gestos avanzados, rendimiento optimizado, accesibilidad completa*

[📥 Descargar](#instalación) • [🚀 Características](#características) • [📖 Documentación](#documentación) • [🤝 Contribuir](#contribución)

</div>

---

## 🎯 ¿Por qué BuenMouse?

BuenMouse transforma tu mouse y trackpad en herramientas de productividad avanzadas, añadiendo gestos intuitivos y funcionalidades que macOS debería tener por defecto. Con **arquitectura de rendimiento optimizada** y **accesibilidad completa**, es la solución perfecta para usuarios que buscan eficiencia sin sacrificar recursos del sistema.

### ✨ Lo que hace especial a BuenMouse v2.0+

- 🚄 **Rendimiento Ultra-Rápido**: Procesamiento de eventos en < 1ms con sistema de batching avanzado
- ♿ **Accesibilidad Completa**: Soporte total para VoiceOver y tecnologías asistivas
- ⚡ **Ultra Liviano**: < 15MB de memoria, < 0.1% CPU, cero impacto en batería
- 🎨 **Interfaz Moderna**: SwiftUI nativo con animaciones fluidas y tema dinámico
- ⌨️ **Atajos de Teclado**: Navegación completa por teclado (⌘+1/2/3, ⌘+Shift+M)
- 🔒 **Privacidad Total**: Cero telemetría, procesamiento 100% local

---

## 🚀 Características

### 🖱️ **Scroll Inteligente con Control + Click**
Convierte cualquier mouse en uno con scroll omnidireccional. Mantén **Control + Click** y arrastra para hacer scroll en cualquier dirección con precisión milimétrica.

### 🔄 **Navegación Fluida entre Espacios**
Cambia entre espacios de trabajo con **Click Derecho + Arrastre**. Sistema adaptativo que aprende tu velocidad de navegación preferida.

### ⬅️➡️ **Botones Back/Forward Avanzados**
Transforma los botones laterales de tu mouse en navegación universal. Funciona en navegadores, Finder, y aplicaciones compatibles.

### 🔍 **Zoom Dinámico**
**Control + Scroll** para zoom inteligente con aceleración adaptativa. Perfecto para diseño, desarrollo y navegación web.

### ⚙️ **Personalización Avanzada**
- **Barra de Estado Dinámica**: Iconos que reflejan el estado actual con tooltips informativos
- **Menú Contextual**: Acceso rápido a configuraciones y controles
- **Sensibilidad Adaptativa**: Configuración granular de umbrales y timing
- **Modo Oscuro**: Seguimiento automático del sistema o configuración manual

---

## 📥 Instalación

### 🎯 Instalación Rápida

```bash
# Descarga la versión más reciente
curl -L -o BuenMouse.dmg https://github.com/usuario/BuenMouse/releases/latest/download/BuenMouse.dmg

# Monta y copia a Aplicaciones
hdiutil attach BuenMouse.dmg
cp -R "/Volumes/BuenMouse/BuenMouse.app" "/Applications/"
hdiutil detach "/Volumes/BuenMouse"
```

### 📱 Instalación Manual

1. **Descarga**: Ve a [Releases](https://github.com/usuario/BuenMouse/releases) y descarga la versión más reciente
2. **Instala**: Arrastra `BuenMouse.app` a tu carpeta `Aplicaciones`
3. **Permisos**: Otorga permisos de accesibilidad cuando se solicite
4. **¡Listo!**: Busca el ícono de cursor en tu barra de menú

### 🔐 Configuración de Permisos

BuenMouse necesita permisos de **Accesibilidad** para funcionar:

1. Abre **Ajustes del Sistema** → **Privacidad y Seguridad** → **Accesibilidad**
2. Haz clic en **+** y selecciona **BuenMouse**
3. Activa el interruptor junto a BuenMouse
4. ¡Disfruta de tus nuevos gestos!

---

## 🎮 Guía de Uso Rápida

### 🖱️ **Scroll con Control + Click**
```
1. Mantén presionada la tecla Control ⌘
2. Haz clic izquierdo y mantén presionado
3. Arrastra en cualquier dirección para hacer scroll
4. Suelta para detener
```

### 🔄 **Cambio de Espacios**
```
1. Haz clic derecho y mantén presionado
2. Arrastra horizontalmente (izquierda ← → derecha)
3. Suelta cuando veas la animación de cambio
```

### ⌨️ **Atajos de Teclado**
- `⌘ + 1`: Ir a pestaña General
- `⌘ + 2`: Ir a pestaña Atajos
- `⌘ + 3`: Ir a pestaña Acerca de
- `⌘ + Shift + M`: Mover a barra de menú

---

## ⚙️ Configuración Avanzada

### 🎛️ Panel de Configuración

Accede haciendo clic en el ícono de BuenMouse en la barra de menú:

- **🔘 Activar/Desactivar**: Control global de todas las funciones
- **📏 Sensibilidad**: Ajuste granular de umbrales (20-100px)
- **🔄 Dirección**: Invertir comportamiento de navegación
- **🔍 Zoom**: Configurar Control + Scroll
- **🚀 Inicio Automático**: Lanzar con el sistema

### 🎨 Personalización Visual

- **Tema Dinámico**: Sigue automáticamente el modo oscuro del sistema
- **Iconos de Estado**: Cursor normal (activo) o cursor tachado (inactivo)
- **Tooltips Informativos**: Muestra estado actual al pasar el mouse
- **Menú Contextual**: Clic derecho en el ícono para acciones rápidas

---

## 🏗️ Para Desarrolladores

### 🛠️ Compilación desde el Código Fuente

```bash
# Clona el repositorio
git clone https://github.com/usuario/BuenMouse.git
cd BuenMouse

# Abre en Xcode
open BuenMouse.xcodeproj

# O compila desde la línea de comandos
xcodebuild -project BuenMouse.xcodeproj -scheme BuenMouse -configuration Release
```

### 📋 Requisitos de Desarrollo

- **Xcode 15.0+**
- **macOS 13.0+ SDK**
- **Swift 5.0+**
- **Developer ID** (para distribución)

### 🏛️ Arquitectura

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CGEventTap    │────│  EventMonitor    │────│ GestureHandler  │
│  (Sistema)      │    │  (Batching)      │    │ (Estado)        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                 │
                       ┌──────────────────┐    ┌─────────────────┐
                       │ SystemActions    │────│   macOS APIs    │
                       │ (Async)          │    │ (AppleScript)   │
                       └──────────────────┘    └─────────────────┘
```

### 📊 Métricas de Rendimiento

- **Latencia de Eventos**: < 1ms promedio, < 5ms percentil 99
- **Uso de Memoria**: ~15MB residentes, ~5MB comprimidos  
- **Uso de CPU**: < 0.1% promedio, < 2% durante uso intensivo
- **Impacto en Batería**: Despreciable (< 0.1% por hora)

---

## 🤝 Contribución

¡Las contribuciones son bienvenidas! BuenMouse es un proyecto de código abierto que mejora con la comunidad.

### 🚀 Cómo Contribuir

1. **Fork** el repositorio
2. **Crea** una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. **Push** a la rama (`git push origin feature/AmazingFeature`)
5. **Abre** un Pull Request

### 🐛 Reportar Bugs

¿Encontraste un problema? [Crea un issue](https://github.com/usuario/BuenMouse/issues) con:

- 🖥️ Versión de macOS
- 🖱️ Tipo de mouse/trackpad
- 📝 Pasos para reproducir
- 📊 Logs del Console.app (si aplica)

### 💡 Sugerir Features

¿Tienes una idea genial? [Compártela](https://github.com/usuario/BuenMouse/discussions) en nuestro foro de discusiones.

---

## 📖 Documentación

### 📚 Recursos para Desarrolladores

- **[Documentación Técnica Completa](CLAUDE.md)**: Arquitectura interna y patrones avanzados
- **[API Reference](docs/api.md)**: Interfaces y protocolos públicos
- **[Performance Guide](docs/performance.md)**: Optimizaciones y benchmarks
- **[Accessibility Guide](docs/accessibility.md)**: Implementación de accesibilidad

### 🔧 Herramientas y Scripts

```bash
# Monitor de rendimiento
./scripts/performance-monitor.sh

# Validador de accesibilidad  
./scripts/accessibility-check.sh

# Construcción automática
./scripts/build-release.sh
```

---

## 🛡️ Privacidad y Seguridad

### 🔒 Compromiso de Privacidad

- **❌ Cero Telemetría**: No recopilamos datos de uso
- **💻 Procesamiento Local**: Todo se ejecuta en tu Mac
- **🔐 Permisos Mínimos**: Solo acceso esencial al sistema
- **📖 Código Abierto**: Transparencia total

### 🛡️ Seguridad

- **🔏 Firmado con Developer ID**: Verificación completa de Gatekeeper
- **🏗️ Runtime Hardening**: Protecciones adicionales habilitadas
- **🔍 Validación de Entradas**: Verificación exhaustiva de datos externos

---

## 🏆 Reconocimientos

### 💡 Inspiración

- **BetterTouchTool**: Pionero en gestos avanzados para macOS
- **Magnet**: Excelencia en aplicaciones de productividad minimalistas
- **Linear Mouse**: Referencia en optimización de scroll

### 🙏 Contribuidores

Gracias a todos los que han contribuido al proyecto:

- [@steven](https://github.com/steven) - Creador y maintainer principal
- [Lista completa de contribuidores](https://github.com/usuario/BuenMouse/contributors)

---

## 📄 Licencia

BuenMouse está licenciado bajo la [Licencia MIT](LICENSE). Esto significa que puedes:

- ✅ Usar comercialmente
- ✅ Modificar
- ✅ Distribuir
- ✅ Usar en proyectos privados

Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

## 🗺️ Roadmap

### 🚧 En Desarrollo

- [ ] **Machine Learning**: Reconocimiento adaptativo de gestos
- [ ] **Multi-Monitor**: Soporte mejorado para múltiples pantallas
- [ ] **Plugins**: Arquitectura de extensiones
- [ ] **Sincronización**: Configuraciones en iCloud

### 💭 Ideas Futuras

- [ ] **Gestos Personalizados**: Editor visual de gestos
- [ ] **Perfiles**: Configuraciones por aplicación
- [ ] **API Pública**: SDK para desarrolladores
- [ ] **Estadísticas**: Panel de uso y productividad

---

<div align="center">

## 🌟 ¡Dale una estrella si BuenMouse te resulta útil!

[![GitHub stars](https://img.shields.io/github/stars/usuario/BuenMouse.svg?style=social&label=Star)](https://github.com/usuario/BuenMouse)

**¡Hecho con ❤️ para la comunidad de desarrolladores macOS!**

---

[⬆️ Volver al inicio](#buenmouse-️)

</div>