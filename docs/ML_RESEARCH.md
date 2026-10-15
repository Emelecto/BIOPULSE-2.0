# Investigación ML — alcance y evidencia

Estado: **CONFIRMED** para la auditoría reproducida y la existencia del pipeline de investigación; **UNKNOWN** para utilidad predictiva real en BioPulse 2.0. Ningún modelo se activa en la app.

## Auditoría heredada

`ml/audit_legacy.py` leyó sin modificar el CSV heredado: 100.000 filas, 286 `user_id`, fechas 2023-01-01 a 2024-02-03, cero duplicados `user_id/date` y cero faltantes explícitos. No hay etiqueta independiente de enfermedad. Procedencia, método de generación y licencia: **UNKNOWN**. En `files/train_real_models.py` las tres etiquetas se construyen con umbrales de las mismas variables que recibe el Random Forest y la evaluación mezcla filas con separación aleatoria. El AUC de aproximadamente 0,994 no demuestra detección de enfermedad; representa reconstrucción de reglas y puede beneficiarse de dependencia entre filas del mismo sujeto.

## Dos familias, con puerta científica

1. **Riesgo/anomalía/enfermedad.** Una desviación personal puede explorarse como señal de bienestar, nunca como diagnóstico. Para `disease_event` y `anomaly_event`, el entrenamiento exige etiquetas independientes (`clinician_adjudicated`, `laboratory_confirmed` o `independent_record`), horizonte temporal y procedencia/licencia/consentimiento documentados. No existen aún tales etiquetas verificadas en el proyecto; esta ruta está bloqueada para publicación.
2. **Sueño/recuperación/rendimiento.** `next_night_sleep_min`, `next_day_recovery` y `next_day_performance` son *outcomes futuros observables*, no scores calculados con los predictores del mismo día. Antes de entrenar se deben fijar instrumento, unidades, instante de predicción y definición de cada outcome. El código compara una mediana/prior simple con gradient boosting y reserva personas no vistas **y** fechas posteriores al corte. Es una plantilla de investigación, no evidencia de calidad ni modelo listo para Core ML.

El pipeline `ml/train_research.py` exige metadatos externos, al menos 100 observaciones y 10 sujetos, bloquea IDs+fechas duplicados, divide por persona y fecha y reporta métricas del baseline y candidato (AUC/precisión promedio/Brier en clasificación; MAE/R² en regresión). No serializa un modelo entrenado. Faltan validación externa, calibración, intervalos de incertidumbre, análisis de subgrupos, estabilidad entre sensores, drift y revisión clínica. No usar datos sintéticos para reclamar rendimiento.

## Estudios primarios que informan el diseño

- [Mishra et al., *Nature Biomedical Engineering* (2020)](https://www.nature.com/articles/s41551-020-00640-6): señales de frecuencia cardiaca, pasos y sueño frente a línea base personal en una cohorte retrospectiva de COVID-19. Justifica explorar anomalías, **no** generalizar a diagnóstico de múltiples enfermedades.
- [Alavi et al., *Nature Medicine* (2021)](https://www.nature.com/articles/s41591-021-01593-2): seguimiento prospectivo con alertas fisiológicas; también hubo alertas por estrés, alcohol y viajes. Motiva separar anomalía de etiología.
- [Quer et al., *Nature Medicine* (2021)](https://www.nature.com/articles/s41591-020-1123-x): datos de wearable y síntomas autoinformados para COVID-19; la definición de evento y la información disponible en el momento de predicción importan.
- [Walch et al., *SLEEP* (2019)](https://pubmed.ncbi.nlm.nih.gov/31579900/): predicción de etapas de sueño con acelerometría y frecuencia cardiaca; es un objetivo diferente a pronosticar el sueño de la noche siguiente.
- [Kapoor y Narayanan, *Patterns* (2023)](https://www.sciencedirect.com/science/article/pii/S2666389923001599): documenta leakage en investigación ML y sustenta controles de etiqueta, sujeto y tiempo.

Estos trabajos no validan por sí mismos los sensores, población ni resultados futuros de BioPulse. Toda comunicación al usuario debe distinguir *medido*, *estimado*, *predicho* y *no disponible*. Nunca emitir diagnóstico o ajuste terapéutico.
