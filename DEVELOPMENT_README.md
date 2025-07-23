# BuenMouse - Development Guide

## 📋 Resumen del Proyecto

BuenMouse es una aplicación de productividad para macOS que mejora la experiencia del mouse con gestos personalizables. La app está diseñada para ejecutarse en segundo plano con mínimo impacto en el rendimiento del sistema.

## 🏗️ Arquitectura del Proyecto

### Estructura de Archivos
```
BuenMouse/
├── AppDelegate.swift              # Delegado principal de la app
├── BuenMouseApp.swift            # Punto de entrada SwiftUI
├── ServiceManager.swift          # Manejo de launch at login
├── WindowAccessor.swift          # Acceso a ventana nativa
├── Core/
│   ├── EventHandling/
│   │   ├── EventMonitor.swift    # Monitor de eventos del sistema
│   │   ├── GestureHandler.swift  # Manejo de gestos
│   │   └── ScrollHandler.swift   # Manejo de scroll
│   ├── Settings/
│   │   ├── SettingsManager.swift # Configuraciones persistentes
│   │   └── SettingsProtocol.swift # Protocolo de configuraciones
│   └── SystemActions/
│       └── SystemActionRunner.swift # Ejecución de acciones del sistema
├── Views/
│   └── ContentView.swift         # Interfaz principal SwiftUI
├── Resources/
│   ├── Assets.xcassets          # Recursos gráficos
│   ├── BuenMouse.entitlements   # Permisos de la app
│   └── Info.plist               # Configuración de la app
└── README.md                    # Documentación pública
```

## 🔧 Componentes Principales

### 1. AppDelegate
- **Propósito**: Maneja el ciclo de vida de la app y la barra de menú
- **Funciones clave**:
  - `setupStatusBar()`: Configura el icono en la barra de menú
  - `setupComponents()`: Inicializa handlers y monitors
  - `updateMonitoring()`: Controla el estado del monitoring
  - `statusItemClicked()`: Maneja clicks en el icono de la barra

### 2. SettingsManager
- **Propósito**: Gestiona todas las configuraciones persistentes
- **Configuraciones**:
  - `isMonitoringActive`: Controla si el monitoring está activo
  - `launchAtLogin`: Inicio automático con macOS
  - `startInMenubar`: Iniciar minimizado en barra de menú
  - `invertDragDirection`: Invertir dirección de arrastre
  - `dragThreshold`: Sensibilidad de arrastre
  - `invertScroll`: Invertir scroll global
  - `enableScrollZoom`: Habilitar zoom con Ctrl+Scroll
  - `isDarkMode`: Modo oscuro manual
  - `followSystemAppearance`: Seguir apariencia del sistema

### 3. EventMonitor
- **Propósito**: Captura y procesa eventos del mouse a nivel del sistema
- **Optimizaciones**:
  - Filtrado temprano de eventos irrelevantes
  - Delegación eficiente a handlers específicos
  - Manejo optimizado de recursos

### 4. ContentView
- **Propósito**: Interfaz principal de la aplicación
- **Características**:
  - Tabs para Settings, Shortcuts y About
  - Grid de 3 columnas para shortcuts
  - Controles deshabilitados cuando monitoring está inactivo
  - Toggle de modo oscuro integrado

## 🎯 Funcionalidades Implementadas

### Gestos del Mouse
1. **Ctrl + Click & Drag**: Scroll como trackpad
2. **Middle Mouse + Drag**: Cambio entre espacios
3. **Mouse Button 3**: Navegación hacia atrás
4. **Mouse Button 4**: Navegación hacia adelante
5. **Ctrl + Scroll**: Zoom (opcional)

### Configuraciones
- ✅ Enable/disable gesture monitoring (controla todas las funciones)
- ✅ Launch at login (funciona correctamente)
- ✅ Start in menubar
- ✅ Drag sensitivity slider
- ✅ Invert drag direction
- ✅ Global scroll inversion
- ✅ Scroll zoom toggle
- ✅ Dark mode toggle con seguimiento del sistema

### Optimizaciones v2.0
- ✅ Eliminadas animaciones innecesarias
- ✅ App oculta del dock (LSUIElement = true)
- ✅ Menu bar completamente funcional
- ✅ Monitoring controlado por configuración principal
- ✅ Event handling optimizado
- ✅ Consumo mínimo de recursos

## 🔄 Flujo de Trabajo de Desarrollo

### Para Agregar Nuevas Configuraciones:
1. Agregar propiedad `@Published` en `SettingsManager.swift`
2. Implementar persistencia con `UserDefaults`
3. Agregar toggle/control en `ContentView.swift`
4. Actualizar lógica en handlers correspondientes

### Para Agregar Nuevos Gestos:
1. Modificar `GestureHandler.swift` o `ScrollHandler.swift`
2. Agregar configuración en `SettingsManager.swift` si es necesario
3. Documentar en la sección de shortcuts
4. Actualizar `README.md`

### Para Optimizaciones de Rendimiento:
1. Revisar `EventMonitor.swift` para filtrado de eventos
2. Eliminar animaciones innecesarias en SwiftUI
3. Optimizar handlers para early returns
4. Verificar uso de memoria y CPU

## 🐛 Problemas Conocidos y Soluciones

### Launch at Login
- **Problema**: No funcionaba correctamente
- **Solución**: Implementado con `SMAppService.mainApp` y verificación de estado

### App en Dock
- **Problema**: Aparecía en el dock
- **Solución**: Agregado `LSUIElement = true` en `Info.plist`

### Animaciones Lentas
- **Problema**: Animaciones causaban lag
- **Solución**: Eliminadas todas las animaciones innecesarias

### Monitoring Control
- **Problema**: Configuraciones funcionaban aunque monitoring estuviera desactivado
- **Solución**: Implementado control centralizado que deshabilita todas las funciones

## 🔧 Configuración de Desarrollo

### Requisitos
- Xcode 14.0+
- macOS 13.0+
- Swift 5.7+

### Permisos Necesarios
- Accessibility (para capturar eventos del mouse)
- Apple Events (para controlar otras aplicaciones)

### Build Settings Importantes
- `LSUIElement = true` (ocultar del dock)
- Entitlements configurados correctamente
- Code signing para distribución

## 📝 Notas de Implementación

### Modo Oscuro
- Implementado con seguimiento automático del sistema
- Toggle manual disponible
- Configuración persistente

### Grid de Shortcuts
- Cambiado de lista vertical a grid de 3 columnas
- Mantiene funcionalidad de expansión
- Mejor uso del espacio en pantalla

### Control de Monitoring
- Configuración principal controla todas las funciones
- UI se deshabilita visualmente cuando está inactivo
- Event monitoring se detiene completamente

## 🚀 Próximas Mejoras Sugeridas

1. **Configuraciones Avanzadas**: Más opciones de personalización
2. **Gestos Personalizados**: Permitir definir gestos custom
3. **Estadísticas de Uso**: Tracking de gestos más utilizados
4. **Exportar/Importar Configuraciones**: Backup de settings
5. **Múltiples Perfiles**: Diferentes configuraciones por contexto

## 🔍 Debugging

### Logs Importantes
- ServiceManager registra estado de launch at login
- EventMonitor muestra eventos capturados
- SettingsManager confirma cambios de configuración

### Herramientas Útiles
- Console.app para logs del sistema
- Activity Monitor para uso de recursos
- Accessibility Inspector para permisos

---

**Última actualización**: Versión 2.0 - Optimizaciones mayores implementadas