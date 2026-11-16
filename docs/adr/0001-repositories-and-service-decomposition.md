# ADR 0001: Repositorios y descomposición en servicios

## Estado
Aceptada

## Contexto
El enunciado exige al menos dos microservicios en Java reactivo (Triage y Asistente Clínico), con integración asíncrona
por Kafka, y pide justificar cualquier descomposición adicional. También pide un repositorio con todo el código.

## Alternativas
1. Un monorepo multimódulo de Gradle con una librería compartida de contratos.
2. Un repositorio por servicio, sin librerías compartidas, y un repositorio de plataforma que los orquesta.

## Decisión
Alternativa 2 (tres repositorios):
- `vidacruz-triage-service`: el servicio de Triage.
- `vidacruz-assistant-service`: el servicio de Asistente Clínico.
- `vidacruz-platform`: `docker-compose.yml`, manifests de Kubernetes, documentación, ADR y el contrato de eventos.

Cada servicio tiene su propio ciclo de vida, su propia versión de Spring Boot y sus propias pruebas. Los servicios no
comparten código: cada uno define su propia copia del modelo del evento, y el contrato se documenta en
`docs/events/triaje-eventos.md`. El asistente lee solo los campos que necesita e ignora los demás.

## Consecuencias
- Despliegue independiente de cada servicio y sin acoplamiento de compilación: el triaje puede evolucionar sin recompilar el asistente.
- El acoplamiento se hace explícito y visible en el contrato de eventos (versionado con el campo `version`).
- Hay una pequeña duplicación (los enumerados de nivel y estado) a cambio de esa independencia.
- Los tres repositorios se orquestan desde la plataforma con una ruta relativa (`../`) o una URL de GitHub; se descartaron los
  submódulos de Git para no añadir complejidad.
- No se añadió ninguna descomposición adicional: la vista de urgencias y el reporte viven en el servicio que posee los datos.