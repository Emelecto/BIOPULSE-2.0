# BioPulse 2.0 — puertas para usuarios reales

Estado revisado el 19-10-2026. **CONFIRMED** significa comprobado en el repositorio o por una prueba indicada; **UNKNOWN** exige una comprobación. La prueba del propietario en su iPhone confirma que la app arranca y navega en ese dispositivo; no reemplaza pruebas con otros usuarios y datos.

## Se puede preparar sin Mac

| Puerta | Estado actual | Criterio para cerrar |
| --- | --- | --- |
| Borrado de cuenta | **CONFIRMED local:** función `account-delete`, interfaz web/iOS y limpieza de archivos/recordatorios en fuente. Seis pruebas del controlador y la integración HTTP con once tablas pasan en Windows. **UNKNOWN:** despliegue alojado y flujo completo iOS. | El iPhone limpia sus archivos y vuelve a acceso; repetir la prueba con cuentas sintéticas tras desplegar. |
| Copia de datos sincronizados | **CONFIRMED local:** descarga JSON por páginas, con RLS y comprobación de sesión. Cinco pruebas de paginación, fallos y cambio de cuenta pasan. Login, descarga real y contenido del archivo comprobados en navegador con una cuenta sintética. | Repetir con una cuenta de prueba en el despliegue alojado; el alcance excluido se explica antes de descargar. |
| Acceso web y correos | **CONFIRMED en fuente:** pantallas y plantillas. **UNKNOWN:** plantillas, URLs y SMTP en Supabase alojado. | Registro, reenvío, recuperación y cambio de correo funcionan para direcciones externas al equipo. |
| Privacidad y soporte | **CONFIRMED en fuente:** inventario técnico `docs/PRIVACY_DATA_INVENTORY.md`. **UNKNOWN:** responsable legal, contacto de soporte, retención, política pública y declaraciones de App Store. | Textos revisados para los países de lanzamiento, URL pública, contacto funcional y descripción exacta de cada proveedor y flujo de datos. |
| Coach IA | **CONFIRMED en fuente:** consentimiento, límites y función. **UNKNOWN:** respuestas reales evaluadas en preguntas sensibles y fallos de red. | Pruebas de seguridad y utilidad, consentimiento/revocación, latencia y errores; si no pasa, ocultarlo en la beta. |
| ML predictivo | **CONFIRMED:** la evaluación supervisada disponible no superó la referencia trivial y no está activa. | Mantener fuera del producto hasta contar con etiquetas independientes, prueba por persona/tiempo y evidencia en Apple Watch. No bloquea una beta honesta de bienestar. |
| QA automatizado | **CONFIRMED local:** build web, 21 pruebas web, seis pruebas del controlador, integración HTTP de borrado, 80 pruebas SQL y análisis sintáctico de Swift. Workflow web preparado para push/PR; aún no ejecutado en GitHub. **UNKNOWN:** flujos alojados y compilación iOS de estos cambios. | CI de web y Swift en verde; regresión alojada con cuentas sintéticas y revisión iPhone. |

## Requiere Mac, iPhone o cuentas externas

1. Abrir el checkout más reciente en Xcode; compilar, instalar y probar el borrado de cuenta de extremo a extremo con una **cuenta sintética**. No usar cuentas personales para esta prueba.
2. Probar Apple Salud con varios usuarios de Apple Watch, diferentes coberturas, días sin sueño/HRV, zonas horarias y permisos. Registrar cuándo aparecen BioScore y Sleep Score y cuándo muestran “datos insuficientes”.
3. Decidir la promesa de lanzamiento: implementar la sincronización nativa iOS por categoría o explicar claramente que los datos de iOS permanecen locales y que la web usa un puente independiente. No presentar continuidad automática entre app y web mientras no exista.
4. Resolver firma y distribución por TestFlight, inicio con Apple si se mantiene Google para la cuenta principal, y pruebas de accesibilidad (Dynamic Type, VoiceOver, contraste) y rendimiento en dispositivos.
5. Completar App Store Connect: política y ficha de privacidad, URL de soporte, capturas reales, cuenta de demostración y revisión de afirmaciones de salud. Una app que crea cuentas debe permitir iniciar su eliminación dentro de la app.

## Integración local del borrado

Con Supabase local activo y la función servida, ejecutar `node supabase/tests/account_delete_http.mjs` desde la raíz. El script se niega a correr contra una URL distinta de `http://127.0.0.1:54321`. **Pasó el 19-10-2026**: comprueba autenticación, confirmación, que un `user_id` falso no seleccione otra cuenta y la eliminación en cascada de once tablas, conservando los registros de la segunda cuenta. La función alojada no se despliega automáticamente al agregar el código.

Antes de activar el borrado alojado, confirmar que ninguna tabla nueva ni objeto de Storage quede fuera de la cascada, y probar el flujo con cuentas sintéticas. Si se habilita Sign in with Apple, incluir la revocación de sus tokens según los requisitos de Apple.
