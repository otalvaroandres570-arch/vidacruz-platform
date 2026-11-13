# ADR 0006: Vista de urgencias como proyección de eventos en Redis

## Estado
Aceptada

## Contexto
RF-04 parte B exige que el asistente informe cuántos pacientes activos hay por nivel reconstruyéndolo
exclusivamente a partir del topic `triaje.eventos`, sin llamar a la API del triaje, y persistiéndolo en Redis o en
una base NoSQL. La entrega de Kafka es al menos una vez y solo ordena los eventos de una misma partición.

## Decisión
- Redis guarda el último estado conocido de cada paciente y un contador de activos por nivel. Un script Lua los
  actualiza de forma atómica.
- Un evento se aplica solo si no retrocede el estado del paciente (REGISTRADO < EN_CONSULTA < ALTA). Los duplicados,
  los escalamientos y los eventos desordenados no cambian la vista, y no hace falta confiar en relojes.
- Los pacientes dados de alta se recuerdan 7 días, para ignorar eventos tardíos sin que la memoria crezca sin límite.
- El consumidor (reactor-kafka) confirma el offset solo después de aplicar el evento, omite los mensajes ilegibles y
  se reinicia con espera creciente ante fallos de Redis o de Kafka.
- El grupo de consumo lee desde el principio: la vista se reconstruye vaciando Redis y reiniciando los offsets.

## Consecuencias
- El asistente funciona aunque el triaje esté caído (usa la última vista conocida), y el triaje no depende del asistente.
- Si se pierde el evento de alta de un paciente, este queda contado como activo hasta que se reconstruya la vista.
- La vista es eventualmente consistente: hay un retraso de unos segundos (relé de la outbox más confirmación del offset).
- Redis no tiene volumen en desarrollo: la proyección es desechable porque se puede reconstruir desde Kafka.