# ML 2.0 — investigación, no producto clínico

Dos rutas separadas: `disease_event` (evento clínico confirmado, inicialmente bloqueada por falta de etiquetas independientes) y `next_day_recovery` / `next_night_sleep` / `next_day_performance` (resultados futuros observados). Todos los ejemplos deben tener `user_id`, `date`, features de la fecha de predicción y una etiqueta medida después. Nunca usar puntuaciones derivadas de las mismas features como verdad clínica.

`python ml/audit_legacy.py <ruta>` inspecciona un CSV sin modificarlo ni imprimir filas o IDs. `python -m unittest discover -s ml/tests` prueba el contrato. El dataset heredado no se incorpora al nuevo repositorio y no genera un modelo publicable. Su licencia/procedencia sigue sin confirmar.

Antes de entrenar se requieren: consentimiento de investigación, procedencia y licencia verificadas, etiquetas independientes auditadas, definición temporal del horizonte, separación por persona y tiempo, prevalencia/calibración, validación externa, evaluación por subgrupos y revisión clínica. La ruta de riesgo no emitirá diagnóstico ni recomendaciones de tratamiento. El código de entrenamiento posterior debe mantener un test final por personas nunca vistas y un corte temporal prospectivo; no aplicar CV aleatoria por filas.
