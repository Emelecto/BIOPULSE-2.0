# ML 2.0 — investigación, no producto clínico

Dos rutas separadas: `disease_event` (evento clínico confirmado, inicialmente bloqueada por falta de etiquetas independientes) y `next_day_recovery` / `next_night_sleep` / `next_day_performance` (resultados futuros observados). Todos los ejemplos deben tener `user_id`, `date`, features de la fecha de predicción y una etiqueta medida después. Nunca usar puntuaciones derivadas de las mismas features como verdad clínica.

`python ml/audit_legacy.py <ruta>` inspecciona un CSV sin modificarlo ni imprimir filas o IDs. `python -m unittest discover -s ml/tests` prueba el contrato. El dataset heredado no se incorpora al nuevo repositorio y no genera un modelo publicable. Su licencia/procedencia sigue sin confirmar.

Antes de entrenar se requieren: consentimiento de investigación, procedencia y licencia verificadas, etiquetas independientes auditadas, definición temporal del horizonte, separación por persona y tiempo, prevalencia/calibración, validación externa, evaluación por subgrupos y revisión clínica. La ruta de riesgo no emitirá diagnóstico ni recomendaciones de tratamiento. El código de entrenamiento posterior debe mantener un test final por personas nunca vistas y un corte temporal prospectivo; no aplicar CV aleatoria por filas.

`train_research.py` compara tres opciones: predictor trivial (referencia mínima), modelo lineal regularizado (relaciones comprensibles) y gradient boosting (posibles relaciones no lineales). Las métricas se miden en personas no vistas después del corte temporal. El resultado está marcado `research_only_not_for_product`; no guarda pesos entrenados ni alimenta los índices visibles. La fórmula visible está en [SCORE_ALGORITHMS.md](../docs/SCORE_ALGORITHMS.md). No existe todavía una etiqueta independiente de descanso percibido estructurada en BioPulse ni un evento clínico válido para entrenamiento.

## Benchmark PMData — 2026-10-17

Se descargó un subconjunto del archivo oficial de [PMData](https://datasets.simula.no/pmdata/) y se evaluó el autorreporte de readiness del día siguiente frente a mediciones Fitbit del día anterior. `prepare_pmdata.py` convierte una extracción de `pmdata.zip` (carpetas `p01`…`p16`) en una tabla privada; `assess_pmdata.py` ejecuta el holdout y añade una referencia de persistencia. No subir la tabla derivada ni datos de participantes al repositorio.

```powershell
python ml/prepare_pmdata.py <carpeta-pmdata-extraida> <carpeta-privada>
python ml/assess_pmdata.py <carpeta-privada>/pmdata_next_day_readiness.csv <carpeta-privada>/pmdata_metadata.json --cutoff 2020-01-15
```

Resultado y límites: [ACTIVATION_REVIEW_2026-10-17.md](ACTIVATION_REVIEW_2026-10-17.md). El resultado fue negativo para activación: los candidatos quedaron por debajo de las referencias simples en personas no vistas. La página actual de Simula y el artículo original discrepan sobre la licencia; hay que aclararla antes de considerar reutilización comercial.
