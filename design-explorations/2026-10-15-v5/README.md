# BioPulse · BioScore orgánico

Tres mockups conceptuales iOS generados con la herramienta de imágenes integrada. Conservan la jerarquía central de la exploración anterior, pero sustituyen el disco rígido por un anillo orgánico. La gráfica de esfuerzo es compacta; HRV, frecuencia cardiaca, sueño y pasos forman una lectura secundaria. El botón flotante «Coach IA» queda sobre la barra de pestañas sin taparlas.

## Direcciones / prompts finales

1. **Membrana viva** (`01-membrana-viva.png`): anillo continuo y translúcido de jade líquido, espesor irregular, ondulación y reflejos internos; superficie más expresiva de las tres. Gráfica de esfuerzo bajo el BioScore y cuatro métricas en dos filas sin tarjetas grandes.
2. **Filamentos vivos** (`02-filamentos-vivos.png`): varios hilos finos que siguen órbitas orgánicas ligeramente desfasadas; alternativa más ligera. Métricas en una banda 2×2 y gráfica estrecha debajo.
3. **Jade orgánico mate** (`03-jade-organico-mate.png`): anillo liso, satinado y poco luminoso; volumen construido con borde interior, sombra suave y deformación asimétrica. Mantiene una lectura compacta de gráfica y métricas.

## Movimiento propuesto para una futura implementación

- El número y las etiquetas permanecen **quietos y nítidos**; solo se desplaza muy lentamente el contorno/material del anillo.
- Un ciclo de respiración/flujo de aproximadamente 8–12 segundos, sin saltos, giros completos, destellos ni pulsos agresivos. La variación geométrica debe ser leve para conservar un centro estable.
- La animación no codifica el valor del BioScore: es una expresión de marca, no un indicador de progreso ni de riesgo.
- Con «Reducir movimiento» activado, mostrar un estado estático. Detener o simplificar el efecto si afecta batería, rendimiento o legibilidad.

**Todos los valores y barras son simulados** (`BioScore 82`, `HRV media 48 ms`, `FC media 62 bpm`, `Sueño 7 h 20`, `Pasos 8.420`). No representan datos reales de usuario, resultados verificados del modelo ni afirmaciones médicas. El cálculo del gráfico de «Esfuerzo del día» debe definirse y validarse antes de implementarlo.
