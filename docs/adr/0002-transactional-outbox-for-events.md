# ADR 0002: Outbox transaccional para publicar eventos

## Estado
Aceptada

## Contexto
Cada cambio relevante del paciente (registro, entrada a consulta, alta, escalamiento) debe publicarse en Kafka
(`triaje.eventos`), pero PostgreSQL y Kafka no comparten transacción. Si se guarda y luego se publica, un fallo entre
ambos pierde el evento o deja datos inconsistentes. El servicio de triaje no debe depender de la disponibilidad de Kafka
ni del asistente.

## Alternativas
1. Publicar tras guardar e ignorar el error: simple, pero pierde eventos en silencio y la vista del asistente se desincroniza.
2. Fallar la petición si Kafka falla: consistente, pero una caída de Kafka impide registrar pacientes.
3. Outbox transaccional: el evento se guarda en la misma transacción que el cambio y un proceso aparte lo publica.

## Decisión
Outbox transaccional (alternativa 3). Los eventos se guardan en la tabla `outbox_event` dentro de la transacción del caso
de uso. Un relé periódico (cada segundo, en lotes de 100) los publica en orden de inserción, marca como publicado solo lo
que el broker confirmó y se detiene en el primer fallo, para no romper el orden de los eventos.

## Consecuencias
- El triaje funciona con Kafka caído; los eventos se publican cuando vuelve.
- Entrega al menos una vez: puede haber duplicados, por eso cada evento lleva `eventId` y los consumidores son idempotentes.
- Hay una latencia pequeña entre el cambio y su publicación (intervalo del relé).
- Una tabla y un proceso más que operar: se vigilan con la métrica `triage.outbox.pending` (eventos sin publicar).
- Con varias réplicas, cada una ejecuta su propio relé y un evento puede publicarse más de una vez (todas leen los mismos
  pendientes). El orden por paciente se conserva dentro de cada réplica y los consumidores deduplican por `eventId`.
  Una evolución posible es un bloqueo consultivo de PostgreSQL (`pg_try_advisory_lock`) para que solo una réplica publique a la vez.