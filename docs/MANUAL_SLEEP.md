# Sueño manual y progreso de scores — 20-10-2026

## Criterios de aceptación

1. Registrar, corregir y eliminar una noche desde Hoy o Sueño, usando la fecha local al despertar. Duración entre 0 y 1440 minutos; descanso y calidad entre 1 y 5; despertares, factores y nota opcionales. Los campos obligatorios no se guardan sin una respuesta explícita.
2. Persistir por cuenta en el directorio local protegido, conservando la lectura de archivos `personal-context-v1.json` anteriores. No escribir en Apple Salud ni subir respuestas al servidor o al Coach.
3. Una sola duración por noche para los scores. Apple Salud tiene prioridad salvo selección explícita del autorreporte. Sin medición, usar la estimación. Con un CSV activo, no mezclar autorreportes de la cuenta con datos potencialmente ajenos del archivo.
4. Sleep Score requiere la noche evaluada y 7 noches anteriores en 14 días. BioScore requiere también el día completo y 14 días anteriores por cada señal fisiológica en 28 días. Contar fechas únicas; no contar el día evaluado ni futuros. Mostrar progreso y motivos de ausencia, sin prometer un plazo si hay huecos.
5. El descanso y calidad percibidos no alteran los pesos de las fórmulas ni generan etapas de sueño. Identificar el autorreporte también cuando entra en la referencia histórica del score.
6. Recordatorio local opcional a las 09:00, editable con precisión de minutos y sujeto al horario silencioso y los permisos de iOS. Tocar el aviso abre el formulario únicamente para la cuenta destinataria. Desactivar/cerrar sesión/eliminar cuenta cancela los avisos de sueño correspondientes.

## Decisiones de fechas y fuentes

- La fecha de la noche es el día local al despertar. Se conserva su fecha civil al viajar, sin desplazarla a otra noche por una conversión de zona horaria.
- Sleep Score muestra la última fecha disponible y la indica explícitamente. BioScore mantiene el último día calendario completo (ayer). Por eso un registro de esta mañana no completa el BioScore de ayer.
- El algoritmo iOS pasa a `personal-v2`: mantiene pesos y ventanas, admite duración de sueño explícitamente cero y deduplica fechas del historial. La web permanece en `personal-v1` y no ofrece todavía este formulario.
- «Construyendo tu referencia» describe cobertura de datos. No implica entrenamiento supervisado, calibración clínica ni validación del resultado.
- Los campos nuevos del archivo de contexto son opcionales para admitir archivos anteriores. Si falla una escritura, no se confirma el guardado y se restaura el estado anterior en memoria.
- El recordatorio usa notificaciones locales; no requiere HealthKit Background Delivery, APNs ni una membresía de pago. La entrega puede variar por Concentración, Resumen programado y otros ajustes de iOS.

## Verificación

- Pruebas de dominio: `BioPulse/Tests/BioPulseDomainTests/SleepReportTests.swift` cubre ventanas, datos insuficientes, ausencia de biometría, prioridad y selección de fuente, duplicados, cero horas, validaciones y serialización de las respuestas.
- **CONFIRMED:** el [run 39518324202](https://github.com/Emelecto/BIOPULSE-2.0/actions/runs/39518324202), con Xcode 26.6 y fuente `2950875`, compiló para simulador y dispositivo iOS sin firma, confirmó la correspondencia del proyecto generado y pasó las 38 pruebas del dominio (incluidas ocho nuevas de sueño manual).
- **Pendiente en iPhone:** verificar navegación y teclado en el formulario, persistencia al reiniciar y al cambiar cuentas, lectura de un archivo anterior, permisos/notificación a una hora cercana y apertura desde una app terminada.
- No se afirma que las pruebas de dominio ni el análisis de sintaxis sustituyan una compilación iOS o la comprobación de notificaciones en un iPhone.
