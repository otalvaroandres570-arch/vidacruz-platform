# ADR 0011: reactor-kafka en lugar de spring-kafka

## Estado
Aceptada

## Contexto
El enunciado penaliza las llamadas bloqueantes en el hilo de eventos y pide integración asíncrona con Kafka y atención al
backpressure. El proyecto se generó con `spring-kafka`.

## Alternativas
1. `spring-kafka` con `KafkaTemplate`: el envío puede bloquear al llamante mientras el productor espera los metadatos del broker.
2. `reactor-kafka`: expone el productor y el consumidor como `Mono` y `Flux`.

## Decisión
`reactor-kafka` en los dos servicios.
- Productor (triaje): idempotente y con `acks=all`. Los tiempos están acotados: `max.block.ms` 3 s, `request.timeout.ms` 3 s y
  `delivery.timeout.ms` 5 s. Un broker caído falla rápido con un error controlado, en lugar de colgar la petición.
- Consumidor (asistente): confirmación manual del offset después de aplicar el evento, lectura de uno en uno y en orden
  (`concatMap`), y reinicio con espera creciente ante fallos.
- Los mensajes ilegibles se omiten sin detener el flujo.

## Consecuencias
- Sin bloqueos en el hilo de eventos, y backpressure natural del flujo reactivo.
- Hay menos ejemplos y menos integración con Spring que con `spring-kafka`; el ciclo de vida se gestiona a mano (`SmartLifecycle`).
- Entrega al menos una vez: los consumidores deben ser idempotentes (la vista de urgencias lo es).