# ADR 0009: Observabilidad

## Estado
Aceptada

## Contexto
El enunciado pide probes de salud y readiness, logs estructurados con correlación y métricas de Micrometer
(clasificaciones por nivel, escalamientos y latencia del LLM como mínimo). El trazado distribuido es un bonus.

## Decisión
- Métricas: Micrometer con exposición en Prometheus (`/actuator/prometheus`), protegida por la API key. Triaje:
  clasificaciones y escalamientos por nivel, alertas y eventos pendientes. Asistente: latencia del LLM y de la
  búsqueda por resultado, consultas por resultado y estado del circuit breaker. Las series por nivel existen
  desde el arranque, en cero. Los indicadores de pendientes se refrescan en segundo plano para no bloquear el
  hilo de eventos.
- Los contadores del triaje se incrementan solo después de confirmarse la transacción, para que un reintento no duplique la cifra.
- Probes: liveness depende solo del estado interno. Readiness del triaje depende de PostgreSQL y no de Kafka (la
  outbox absorbe la caída). Readiness del asistente no depende de Redis, Kafka ni Gemini (el servicio degrada:
  503 en el endpoint afectado, no sale de servicio).
- Logs: texto legible en local y JSON de una línea por evento con el perfil `json` (contenedores y Kubernetes).
- Correlación: Micrometer Tracing con OpenTelemetry. Cada petición recibe un `traceId` presente en sus logs. No se
  configura exportador: los identificadores se generan y se ven en los logs, pero las trazas no se envían a ningún colector.
- Los logs no incluyen datos personales ni clínicos: ni nombres, ni signos vitales, ni el texto de las consultas al asistente.

## Consecuencias
- Los trabajos periódicos y los flujos asíncronos no tienen `traceId`: se siguen por el id del paciente.
- El `traceId` no viaja en los eventos de Kafka. Seguir un caso de extremo a extremo exige buscar por el id del paciente
  en los dos servicios. Evolución: propagar el contexto de la traza en las cabeceras del mensaje y exportar a un colector (OTLP).
- Los logs escritos fuera del flujo reactivo de una petición pueden salir sin `traceId`.
- Con el 100 % de muestreo y sin exportador, el coste es bajo; con un colector habría que revisar la tasa de muestreo.