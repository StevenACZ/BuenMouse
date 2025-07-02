# BuenMouse 🖱️

Una aplicación de productividad para macOS que mejora la experiencia del mouse con gestos personalizables y funcionalidades avanzadas.

## ✨ Características

- **Control + Click para Scroll**: Usa Control + Click y arrastra para hacer scroll
- **Gestos de Trackpad**: Navegación entre espacios de trabajo con gestos
- **Botones Especiales**: Botones back/forward del mouse para navegación
- **Scroll Invertido**: Opción para invertir la dirección del scroll
- **Zoom con Scroll**: Zoom in/out con Control + Scroll
- **Configuraciones Persistentes**: Todas las configuraciones se guardan automáticamente

## 🏗️ Estructura del Proyecto

```
BuenMouse/
├── AppDelegate.swift
├── BuenMouseApp.swift
├── ServiceManager.swift
├── WindowAccessor.swift
├── Core/
│   ├── EventHandling/
│   │   ├── EventMonitor.swift
│   │   ├── GestureHandler.swift
│   │   └── ScrollHandler.swift
│   ├── Settings/
│   │   ├── SettingsManager.swift
│   │   └── SettingsProtocol.swift
│   └── SystemActions/
│       └── SystemActionRunner.swift
├── Views/
│   └── ContentView.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── BuenMouse.entitlements
│   └── Info.plist
└── README.md
```

## 🔧 Configuración

### Requisitos
- macOS 13.0 o superior
- Permisos de accesibilidad habilitados

### Instalación
1. Clona el repositorio
2. Abre `BuenMouse.xcodeproj` en Xcode
3. Compila y ejecuta la aplicación
4. Habilita los permisos de accesibilidad cuando se solicite

## 🎯 Funcionalidades Principales

### Control + Click para Scroll
- Mantén presionado Control + Click izquierdo
- Arrastra el mouse para hacer scroll
- Perfecto para navegación precisa

### Gestos de Trackpad
- Click derecho + arrastre horizontal para cambiar espacios
- Configurable el umbral de sensibilidad
- Opción para invertir la dirección

### Botones Especiales del Mouse
- Botón 3 (back): Navegación hacia atrás
- Botón 4 (forward): Navegación hacia adelante
- Con protección contra doble-click

### Scroll Avanzado
- Inversión de scroll global
- Zoom con Control + Scroll
- Detección automática de trackpad vs mouse

## 🛠️ Desarrollo

### Estructura Modular
El proyecto está organizado en módulos especializados:

- **Settings**: Gestión de configuraciones persistentes
- **EventHandling**: Procesamiento de eventos del sistema
- **SystemActions**: Ejecución de acciones del sistema macOS
- **Views**: Interfaces de usuario SwiftUI

### Agregar Nuevas Funcionalidades

1. **Nuevas Configuraciones**: Agregar en `Core/Settings/SettingsManager.swift`
2. **Nuevos Gestos**: Implementar en `Core/EventHandling/GestureHandler.swift`
3. **Nuevas Acciones**: Agregar en `Core/SystemActions/SystemActionRunner.swift`
4. **Nuevas Vistas**: Crear en `Views/`

## 📝 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo LICENSE para más detalles.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor, abre un issue o pull request para sugerencias y mejoras.

---
**Hecho con ❤️ y mucho Swift en Perú.**
