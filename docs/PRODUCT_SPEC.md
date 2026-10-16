# BioPulse 2.0 — especificación de producto

## Estado

- **CONFIRMED:** se desarrollará una aplicación de salud, recuperación y rendimiento físico para cualquier persona interesada en entender o mejorar su salud o rendimiento.
- **CONFIRMED:** la plataforma objetivo es iOS nativo.
- **CONFIRMED:** se priorizan una interfaz premium, oscura y minimalista; datos reales de Apple HealthKit/Apple Watch; importación CSV como respaldo; análisis de bienestar general, recuperación, HRV, sueño, actividad y tendencias fisiológicas; privacidad y almacenamiento local.
- **CONFIRMED:** `BioScore` representa principalmente bienestar general, no exclusivamente capacidad de entrenamiento del día.
- **CONFIRMED:** no se crearán datos fisiológicos artificiales para completar o aparentar lecturas del Apple Watch.
- **PROPOSED:** primera versión funcional en aproximadamente cuatro semanas.
- **CONFIRMED:** iOS 17 es la versión mínima; el primer dispositivo de prueba será un Apple Watch Ultra, con compatibilidad guiada por capacidades para otros modelos.
- **UNKNOWN:** versión mínima de watchOS, alcance clínico, requisitos regulatorios y definición final de éxito.

## Alcance objetivo

La aplicación debe ayudar a una persona a observar y entender su recuperación a partir de datos fisiológicos, sin convertir el producto en una herramienta diagnóstica. La experiencia debe distinguir entre:

- datos observados desde HealthKit o CSV;
- métricas derivadas por reglas transparentes;
- inferencias o estimaciones;
- predicciones de modelos.

## Capacidades previstas

1. Lectura autorizada y consciente de disponibilidad de los datos relevantes de Apple HealthKit/Apple Watch.
2. Importación y validación de CSV como fuente complementaria.
3. Persistencia local y control de privacidad.
4. Visualización de métricas, tendencias, cobertura y contexto temporal.
5. Analítica reproducible de bienestar general, recuperación, HRV, sueño, actividad y workouts.
6. Modelos de ML solo cuando exista evidencia de utilidad, validación y baseline.

## Alcance funcional confirmado

Las siguientes capacidades forman parte del producto objetivo y no deben perderse
al reducir el alcance de una primera entrega:

1. Diario contextual de hábitos, síntomas y eventos.
2. Explicación y glosario de cada métrica.
3. Visualizaciones con contexto, cobertura y procedencia.
4. `BioScore` de bienestar general y `Sleep Score`.
5. Registro de hábitos y análisis exploratorio de sus asociaciones.
6. Sesiones de respiración guiada.
7. Perfil del usuario, objetivos y contexto personal.
8. Mapa de energía del día.
9. Vista técnica para usuarios avanzados y para presentar la ciencia de datos.
10. Tendencias y previsiones descriptivas, claramente diferenciadas de predicciones clínicas.
11. Resumen semanal.
12. Centro de privacidad, permisos, exportación y control de datos.

El Coach BioPulse basado en IA es un pilar estratégico. Está confirmado Groq
como proveedor inicial mediante backend intercambiable: una autorización
explícita única antes del primer envío, métricas derivadas/tendencias/contexto
del Diario y ninguna muestra original de HealthKit. El backend no conservará
transcripts; mantendrá solo un resumen de memoria hasta siete días. El Coach
será en español, informativo y no diagnóstico; antes de publicarlo se requieren
interfaz, evaluación breve de seguridad y configuración de secretos/cuotas.

Cuentas e inicio de sesión son obligatorios para usar BioPulse. No habrá modo
invitado: las funciones solo estarán disponibles con una sesión autenticada
vigente. El registro e inicio de sesión admitirán Iniciar sesión con Apple,
correo/contraseña y Google. Los datos locales y las cachés se aislarán por
identificador de cuenta para impedir que otra cuenta del mismo dispositivo vea
la información.

Iniciar sesión no autoriza por sí solo la sincronización. La sincronización
cloud será opcional y requerirá consentimiento por categoría. Los datos
biométricos originales de HealthKit permanecerán en el dispositivo por
defecto; perfil, diario, configuraciones y métricas derivadas podrán
sincronizarse únicamente con consentimiento explícito.

Los scores, previsiones y asociaciones solo podrán mostrarse cuando sus entradas,
fórmulas y criterios de calidad estén documentados. Una función puede estar
presente en la interfaz sin mostrar un resultado si no existen datos suficientes.

`BioScore` y `Sleep Score` estarán visibles desde el MVP. Mientras sus fórmulas
o datos reales no estén listos, deben mostrar estado pendiente, entradas
necesarias y limitaciones, nunca una cifra de demostración presentada como real.

## No objetivos de la primera fase técnica

- Diagnosticar enfermedades.
- Presentar datos sintéticos como datos del usuario.
- Enviar datos originales de HealthKit a la nube por defecto.
- Reutilizar automáticamente la arquitectura web anterior.

El requisito de cuenta aplica desde el primer flujo utilizable de BioPulse.
La sincronización cloud sigue siendo posterior y opcional. El Coach tiene ya
una base de backend y una interfaz en desarrollo; no estará activo para usuarios
hasta configurar Groq, desplegar la función y pasar validación de seguridad.

## Criterios de aceptación iniciales

- La app compila y ejecuta en un proyecto iOS reproducible.
- Los permisos y fuentes de datos están explicados al usuario.
- La app identifica datos disponibles, ausentes, restringidos, estimados y no compatibles.
- CSV inválidos o incompletos producen errores comprensibles.
- Cada métrica visible tiene una fuente y definición documentadas.
- Los resultados inferidos o predichos incluyen su etiqueta y limitaciones.
- Las pruebas cubren parsing, cálculos principales, persistencia y casos sin datos.

## Ideas de expansión e implementación

La iteración 2026-10-15 incorporó al código fuente la expansión de landing, vistas iOS locales y personalización descritas en [backlog de producto](PRODUCT_BACKLOG.md). La landing pasó revisión en navegador; el iOS todavía requiere compilación y QA en Mac/Xcode, por lo que las nuevas vistas no deben considerarse verificadas ni publicadas. Widgets/complicaciones Apple Watch siguen futuros. La beta web continúa desactivada. Las restricciones de privacidad, procedencia y evidencia de esta especificación prevalecen.
