# ADR 0003: Monitor de SLA por sondeo con actualización condicional

## Estado
Aceptada

## Contexto
RF-03 pide escalar automáticamente a los pacientes que superan su SLA sin haber entrado a consulta, de forma
idempotente (RN-03): un paciente se escala una sola vez y nunca si está en consulta o de alta. El enunciado deja
libre el mecanismo (scheduler, consumidor o equivalente) y exige intervalo y SLA configurables.

## Alternativas
1. Temporizador en memoria por paciente: preciso, pero se pierde al reiniciar y no funciona con varias réplicas.
2. Mensajes diferidos en Kafka: Kafka no tiene entrega diferida nativa.
3. Sondeo periódico sobre PostgreSQL: simple, sin estado en memoria, tolera reinicios y réplicas.

## Decisión
Sondeo periódico (cada 10 s por defecto) sobre los pacientes `REGISTRADO` sin escalar con el SLA vencido
(índice parcial). Cada paciente se escala en su propia transacción con una actualización condicional
(`WHERE status = 'REGISTRADO' AND escalated = FALSE`), que guarda el flag, la auditoría y el evento en la outbox.

## Consecuencias
- La idempotencia la garantiza la base de datos, no el código: con varias réplicas o ciclos solapados solo
  una actualización afecta la fila.
- La precisión del escalamiento es la del intervalo del sondeo (hasta 10 s de retraso con la configuración por defecto).
- El SLA se guarda en cada paciente al registrarlo: cambiar la configuración no altera a los ya registrados.
- "Superó su SLA" se interpreta como estrictamente posterior al plazo.
- Un fallo persistente con un paciente concreto detendría el lote y se reintentaría en cada ciclo; se vigila con los logs.