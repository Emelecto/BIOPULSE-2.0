# Preview navegable de BioPulse 2.0

Esta carpeta contiene una preview web local para revisar la dirección visual y la navegación de la aplicación iOS mientras no haya una Mac con Xcode.

## Ejecutar en Windows

Desde la carpeta `BioPulse`, ejecuta:

```powershell
python -m http.server 4173
```

Después abre `http://127.0.0.1:4173/Preview/`.

La preview usa el mismo recurso visual del bosque que la interfaz SwiftUI, pero no se conecta a HealthKit, no procesa datos biométricos y no guarda los archivos seleccionados. Los estados conectados son únicamente demostrativos para revisar la navegación.

Permite recorrer Hoy, Tendencias, Diario, Sueño y Perfil; abrir BioScore,
Sleep Score, Mapa de energía, Respiración, Resumen semanal, Vista técnica,
Cuenta, Privacidad y Coach. El Diario acepta entradas locales para probar el
flujo, pero se borran al recargar la página y no se transmiten.
