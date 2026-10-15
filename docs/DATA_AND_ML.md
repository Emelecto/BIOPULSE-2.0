# BioPulse 2.0 — datos y machine learning

Actualización 2026-10-15: ver [contrato de sincronización](DATA_SYNC_CONTRACT.md) y [auditoría e investigación ML](ML_RESEARCH.md). Las predicciones clínicas siguen bloqueadas; no hay un modelo 2.0 validado.

## Reglas obligatorias

Todo modelo debe documentar dataset, licencia/procedencia, unidad de análisis, variables, transformaciones, etiqueta, separación temporal o por persona, control de leakage, baseline, métricas, incertidumbre y limitaciones.

Una predicción nunca es una medición fisiológica ni un diagnóstico. Los datos sintéticos, simulados o inferidos deben estar etiquetados en la interfaz y en los artefactos de evaluación.

## Inventario auditado del proyecto anterior

- `whoop_fitness_dataset_100k.csv`: presente en el repositorio antiguo; el script `files/train_real_models.py` usa variables como HRV, RHR, baselines, recovery, sueño, respiración, temperatura, strain, despertares y edad.
- `converted-health-data.csv`: presente; tamaño aproximado observado: 31 MB. Su esquema y procedencia exactos no se han verificado.
- Carpetas `Fitabase Data 3.12.16-4.11.16`, `open-wearables` y `Datasets generados artificalmente`: presentes, pero no auditadas exhaustivamente.
- `files/training_results.json` y gráficas de ROC/CV/confusión: presentes; deben rastrearse hasta una ejecución reproducible antes de usarse como evidencia.

## Código heredado observado

`bioUtils.js` contiene:

- generación demo con semilla fija;
- `computePipeline` con scores derivados, línea base, z-scores en ventanas, ApEn y flags;
- inferencias de fracción de sueño profundo y RHR durante el sueño;
- proyección lineal de `riskScore`;
- correlaciones exploratorias entre logs y métricas.

`train_real_models.py` deriva etiquetas deterministas para recuperación, patrón agudo y proceso infeccioso, entrena Random Forest con split 80/20 y CV estratificada de 5 folds. `train_predict.py` entrena un Random Forest regresor con un objetivo a tres días y reporta únicamente R² de entrenamiento. Esto último no es suficiente para validar un modelo de producción.

## Riesgos científicos pendientes

- Las etiquetas heredadas son reglas derivadas de las mismas variables que alimentan los modelos; esto puede producir leakage conceptual o rendimiento inflado.
- Los valores de ROC visibles en `Technical.jsx` no deben aceptarse sin reconciliarlos con `training_results.json` y una ejecución desde cero.
- No se ha confirmado la identidad de sujetos, dependencia temporal, duplicados, faltantes, licencia ni representatividad.
- No existe todavía una definición 2.0 de outcome clínico o de rendimiento.
- ApEn, reglas de fiebre y scores de recuperación requieren revisión de unidades, ventana, baseline y validez de uso.

## Plan de datos 2.0

1. Definir un esquema canónico y unidades para HealthKit y CSV.
2. Crear un catálogo de fuentes y licencias.
3. Separar datos de desarrollo, validación y fixtures sintéticos.
4. Definir outcomes observables y evitar etiquetas construidas directamente con features.
5. Establecer baseline simple antes de modelos complejos.
6. Validar por persona y, cuando aplique, temporalmente.
7. Registrar semillas, versiones, configuración y métricas.
8. Evaluar calibración, sensibilidad, especificidad, precisión, recall, F1 y ROC-AUC según el caso.
9. Documentar límites y no habilitar predicciones en producto hasta completar revisión.
