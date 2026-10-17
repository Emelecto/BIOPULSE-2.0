# Revisión de activación de ML — 17 de octubre de 2026

## Decisión

**No activar un modelo predictivo en BioPulse 2.0 con los datos disponibles.** Es una decisión basada en una evaluación externa: el candidato entrenado no superó las referencias simples al estimar el autorreporte de readiness del día siguiente en personas no vistas. Tampoco existe un modelo validado para Apple Watch ni una etiqueta clínica independiente que permita afirmar detección de enfermedad.

BioScore, Sleep Score y la señal de cambio `personal-v1` son **cálculos deterministas exploratorios**, no modelos entrenados. La web 2.0 los muestra con su cobertura y explicación cuando hay historial suficiente. No se presentan como diagnósticos ni probabilidades de enfermedad.

## Evidencia disponible

| Fuente | Lo comprobado | Por qué no autoriza activación de ML |
|---|---|---|
| `whoop_fitness_dataset_100k.csv`, solo en el proyecto heredado | Auditoría reproducida: 100.000 filas, 286 IDs, fechas 2023-01-01 a 2024-02-03, sin duplicados usuario/fecha | Procedencia y licencia desconocidas. No hay etiqueta clínica independiente. Los objetivos de enfermedad del código heredado se construyeron con reglas sobre las mismas entradas, por lo que su AUC no prueba detección real. |
| `converted-health-data.csv`, solo en el proyecto heredado | 233.495 filas, 26 tipos de registro; columnas `type, sourceName, unit, startDate, endDate, value` | Es un export de mediciones sin `user_id` ni etiqueta de resultado independiente. No permite evaluar generalización entre personas ni validar recuperación autoinformada o enfermedad. |
| CSV bajo `Datasets generados artificalmente realistas/` | Los archivos se identifican como generados artificialmente | Sirven para desarrollo de software, no para reclamar rendimiento sobre personas reales. |
| `ml/train_research.py` de BioPulse 2.0 | Pipeline que compara baseline trivial, modelo lineal y gradient boosting; exige metadatos y separación por sujeto y tiempo | Es una herramienta de investigación. No guarda pesos ni expone predicciones al producto. Las cuatro pruebas del contrato usan un fixture artificial y validan mecánica de software, no rendimiento fisiológico. |
| [PMData de Simula](https://datasets.simula.no/pmdata/) | 16 personas durante cinco meses con Fitbit Versa 2 y cuestionario PMSys independiente del sensor | Permite un benchmark real de readiness autoinformada, pero no valida Apple Watch ni un motor de riesgo clínico. Los candidatos no mejoraron las referencias simples en el holdout. |

## Qué se verificó en esta revisión

- `ml/audit_legacy.py` reprodujo el inventario del CSV WHOOP heredado sin modificarlo ni imprimir filas privadas.
- Se inspeccionó el esquema y el número de registros del export Apple Salud, sin mostrar valores personales.
- Las cuatro pruebas del contrato ML pasaron con el entorno virtual del proyecto.
- Se inspeccionó el repositorio 2.0: no contiene `.pkl`, `.joblib`, `.onnx`, `.mlmodel` o `.mlpackage` de un modelo listo para activar.
- Se descargaron desde el `pmdata.zip` oficial los archivos de readiness, FC en reposo, pasos y sueño de los 16 participantes. La tabla derivada permanece en `.codex-ml-research/`, excluida de Git.

## Evaluación externa de readiness futura

**Objetivo definido:** a fin del día `d`, predecir el readiness que la persona registra en PMSys el día calendario `d+1` (escala 0–10). Las entradas son FC en reposo, pasos y minutos de sueño del día `d`. Se exigió un autorreporte en ambos días consecutivos y observaciones de pasos y sueño en `d`. No se usó el readiness futuro como entrada; la persistencia del readiness conocido en `d` se evaluó por separado como referencia adicional.

El adaptador produjo **1.268 pares de 16 personas** entre 2019-11-02 y 2020-03-29. Con la partición fija del pipeline (`random_state=42`) y corte 2020-01-15, el entrenamiento usó **482 filas / 12 personas** anteriores al corte; la prueba usó **199 filas / cuatro personas no vistas** desde el corte (`p01`, `p02`, `p06`, `p15`). Las filas restantes no entraron en entrenamiento ni prueba. Esta evaluación es de un solo holdout, no una validación externa de Apple Watch.

| Método | MAE en readiness 0–10 | R² |
|---|---:|---:|
| Mediana de entrenamiento | **1,4824** | −0,0583 |
| Readiness conocido en `d` (persistencia) | **1,4824** | −0,2863 |
| Regresión Ridge | 1,7064 | −0,2949 |
| Gradient boosting | 2,0065 | −0,8688 |

**Resultado:** el modelo lineal y el no lineal fueron peores que la predicción mediana en MAE y R². La persistencia empató en MAE, pero tuvo peor R². Por ello el experimento no justifica pesos entrenados ni activar predicciones en el producto. La FC en reposo tuvo cobertura del 81,94 % en los pares; cuatro de las siete features esperadas (`hrv_sdnn`, frecuencia respiratoria, energía activa y ejercicio) no estaban en esta tabla y quedaron ausentes. La muestra de prueba abarca solo cuatro personas; no se deben extrapolar esas cifras a la población objetivo.

Reproducción desde el archivo oficial extraído:

```powershell
ml\.venv\Scripts\python.exe ml\prepare_pmdata.py <carpeta-pmdata-extraida> <carpeta-privada>
ml\.venv\Scripts\python.exe ml\assess_pmdata.py <carpeta-privada>\pmdata_next_day_readiness.csv <carpeta-privada>\pmdata_metadata.json --cutoff 2020-01-15
```

**Licencia por aclarar:** la [página actual de Simula](https://datasets.simula.no/pmdata/) declara **CC BY 4.0**, mientras el [artículo original de los autores](https://web-backend.simula.no/sites/default/files/publications/files/3339825.3394926.pdf) declara **CC BY-NC 4.0**. No presumir permiso comercial inequívoco hasta resolver esa contradicción con la fuente. La investigación interna aquí no incluye redistribución de registros.

## Puerta mínima para una predicción no clínica

1. Definir un resultado futuro observable, por ejemplo duración de la noche siguiente o recuperación autoinformada, con instante de predicción y unidad. No usar BioScore o una regla calculada desde las entradas como etiqueta.
2. Obtener datos reales de varias personas con permiso de investigación/uso comercial compatible, procedencia documentada, fechas y etiqueta obtenida después del instante de predicción.
3. Separar personas y tiempo entre entrenamiento y prueba; reservar un conjunto externo independiente, idealmente con Apple Watch en la población objetivo.
4. Comparar el candidato con un baseline simple y publicar métricas, intervalos de incertidumbre, cobertura, sesgos por subgrupo y casos de datos faltantes.
5. Integrar solo si aporta beneficio medible y el resultado puede explicarse como predicción exploratoria con sus límites. Validar la implementación final en iPhone antes de mostrarla como función disponible.

[PhysioNet BIDSleep](https://physionet.org/content/bidsleep-dataset/1.0.1/) ofrece señales de Apple Watch y etiquetas EEG para **etapas de sueño**; ese objetivo es distinto de predecir la recuperación o la noche siguiente. [IFH Affect en Dryad](https://datadryad.org/dataset/doi:10.7280/D1WH6T) contiene Oura y Samsung con encuestas de afecto de 21 estudiantes, pero su descarga completa mide 8,59 GB y tampoco representa la población Apple Watch. Estas fuentes son candidatas para investigación posterior, no validación del motor de riesgo propuesto.

## Próximo desbloqueo

La siguiente evaluación necesita datos de Apple Watch de la población objetivo, consentimiento y resultados futuros independientes, más un conjunto externo de prueba. El motor de riesgo clínico requeriría además etiquetas clínicas independientes. Hasta entonces, en la exposición se pueden mostrar los índices exploratorios activos y el experimento ML real, incluido su resultado negativo, sin atribuir a BioPulse una precisión predictiva que no se ha demostrado.
