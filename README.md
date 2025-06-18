# BuenMouse 🖱️✨

![BuenMouse Icon](https://github.com/StevenACZ/BuenMouse/blob/main/BuenMouse/Assets.xcassets/AppIcon.appiconset/BuenMouse%201024.png?raw=true)

**BuenMouse** es una utilidad ligera y potente para macOS diseñada para mejorar tu productividad y flujo de trabajo, devolviéndote el control sobre los gestos de tu ratón. Creado como una solución personal para reemplazar herramientas más pesadas, BuenMouse se enfoca en hacer una cosa y hacerla excepcionalmente bien.

## ✨ Características Principales

-   **Gestos del Clic Central Inteligentes:**
    -   **Clic Rápido:** Abre **Mission Control** al instante para tener una vista general de todas tus ventanas.
    -   **Arrastre con Clic Central:** Cambia entre tus Espacios/Escritorios deslizando el ratón hacia la izquierda o la derecha mientras mantienes presionado el botón central.
-   **Totalmente Personalizable:**
    -   **Sensibilidad de Arrastre:** Ajusta con un slider la distancia que necesitas mover el ratón para activar el cambio de espacio. ¡Desde un movimiento sutil hasta un gesto largo y deliberado!
    -   **Invertir Dirección:** ¿Prefieres que el movimiento sea "natural" o invertido? Puedes cambiarlo con un solo clic.
-   **Ligero y Eficiente:** Sin funciones innecesarias. BuenMouse está diseñado para consumir mínimos recursos del sistema y ejecutarse discretamente en segundo plano.
-   **Control Total:** Gestiona la aplicación desde una ventana de ajustes simple o muévela a la barra de menús para un acceso rápido y sin distracciones.
-   **Abrir al Iniciar Sesión:** Configura BuenMouse para que se inicie automáticamente con tu Mac y esté siempre listo para ti.

## 🚀 Instalación

Actualmente, la forma de instalar BuenMouse es compilándolo directamente desde el código fuente usando Xcode.

1.  **Clona el repositorio:**
    ```bash
    git clone https://github.com/StevenACZ/BuenMouse.git
    ```
2.  Abre el archivo `BuenMouse.xcodeproj` en Xcode.
3.  Selecciona tu equipo de desarrollador personal en la pestaña `Signing & Capabilities`.
4.  Compila y ejecuta la aplicación (▶️).
5.  Una vez compilada, puedes archivarla (`Product -> Archive`) y exportarla como una aplicación (`.app`) para moverla a tu carpeta de Aplicaciones.

**Nota sobre los Permisos:**
La primera vez que ejecutes BuenMouse, macOS te pedirá que concedas dos permisos necesarios para su funcionamiento:
-   **Accesibilidad:** Para poder escuchar los clics del ratón.
-   **Automatización (System Events):** Para poder activar Mission Control y cambiar de espacio.

Debes conceder ambos permisos para que la aplicación funcione correctamente.

## 🛠️ Cómo Usar

1.  **Inicia la aplicación.** Verás la ventana de configuración.
2.  **Activa el monitoreo:** Asegúrate de que el toggle "Activar monitoreo de gestos" esté encendido.
3.  **Personaliza tus ajustes:**
    -   Ajusta la sensibilidad de arrastre a tu gusto.
    -   Activa la inversión de dirección si lo prefieres.
    -   Activa "Abrir al iniciar sesión" para máxima comodidad.
4.  **Mueve la app a la barra de menús:** Haz clic en "Mover a la Barra de Menús" para ocultar la ventana principal y mantener la app corriendo discretamente. Puedes hacer clic en el ícono para volver a abrir la ventana de ajustes cuando quieras.
5.  **¡Disfruta de tu nuevo flujo de trabajo!**

## 💡 Motivación

Este proyecto nació de la necesidad de una herramienta de gestos de ratón simple, fiable y que no fallara. Después de experimentar problemas de estabilidad con otras soluciones, decidí tomar el control y construir una aplicación desde cero que hiciera exactamente lo que necesitaba. BuenMouse es el resultado de un viaje de aprendizaje, depuración y la búsqueda de la herramienta perfecta.

## 🤝 Contribuciones

Aunque este es un proyecto personal, las ideas y sugerencias son siempre bienvenidas. Si tienes alguna idea para una nueva característica o una mejora, no dudes en abrir un "Issue" en GitHub.

---
**Hecho con ❤️ y mucho Swift en Perú.**
