# Contrato de eventos: topic `triaje.eventos`

Productor: **triage-service**. Consumidores: **assistant-service** (y los que se añadan).

## Topic

| Propiedad            | Valor                              |
|----------------------|------------------------------------|
| Nombre               | `triaje.eventos`                   |
| Particiones          | 3                                  |
| Clave del mensaje    | `patientId` (UUID como texto)      |
| Formato del valor    | JSON en UTF-8, sin schema registry |
| Versión del contrato | `1` (campo `version`)              |

La clave garantiza el **orden de los eventos de un mismo paciente**. No hay orden entre pacientes distintos.

## Tipos de evento

Los cuatro nombres vienen del enunciado y se usan tal cual en el campo `type`.

| `type`                 | Cuándo se publica                                   |
|------------------------|-----------------------------------------------------|
| `paciente_registrado`  | Al registrar un paciente (`POST /triage/pacientes`) |
| `paciente_en_consulta` | Al pasar a `EN_CONSULTA`                            |
| `paciente_alta`        | Al pasar a `ALTA`                                   |
| `paciente_escalado`    | Cuando el monitor de SLA escala a un paciente       |

## Estructura del mensaje

```json
{
  "eventId": "7d6f3c1e-0b5a-4c1e-9a52-5f0e2f9d1a11",
  "type": "paciente_registrado",
  "version": 1,
  "occurredAt": "2026-11-12T17:55:19.473818Z",
  "patientId": "3c608219-a3f2-4968-aa6d-a1180a5a36d8",
  "level": "CRITICO",
  "status": "REGISTRADO",
  "previousStatus": null,
  "slaMinutes": 5
}
```

| Campo            | Tipo            | Descripción                                                                     |
|------------------|-----------------|---------------------------------------------------------------------------------|
| `eventId`        | UUID            | Identificador único del evento, para deduplicar                                 |
| `type`           | string          | Uno de los cuatro tipos de arriba                                               |
| `version`        | entero          | Versión del contrato                                                            |
| `occurredAt`     | ISO 8601 (UTC)  | Momento en que ocurrió el hecho (no el de publicación)                          |
| `patientId`      | UUID            | Paciente al que se refiere                                                      |
| `level`          | string          | `CRITICO`, `URGENTE`, `URGENTE_2`, `NO_URGENTE`, `NO_URGENTE_2`                 |
| `status`         | string          | Estado del paciente **después** del evento: `REGISTRADO`, `EN_CONSULTA`, `ALTA` |
| `previousStatus` | string o `null` | Estado anterior; `null` en `paciente_registrado`                                |
| `slaMinutes`     | entero          | SLA asignado al paciente                                                        |

En `paciente_escalado`, `status` y `previousStatus` son ambos `REGISTRADO` (el escalamiento no cambia el estado, solo marca un flag).

## Decisiones

- **Sin datos personales:** el evento no incluye nombre, edad, signos vitales ni queja principal. Quien necesite el detalle lo consulta en la API de triaje. Así, un topic que puede tener muchos consumidores no se convierte en una copia de datos clínicos.
- **Estado resultante en el mensaje:** cada evento dice en qué quedó el paciente (`status`), no solo qué pasó. Un consumidor puede reconstruir su vista aplicando "paciente X está en el estado Y con el nivel Z", sin depender de haber visto todos los eventos anteriores.
- **Entrega al menos una vez:** un mensaje puede llegar duplicado. Los consumidores deben ser idempotentes (por `eventId` o aplicando el estado resultante).
- **Evolución:** añadir campos opcionales no cambia `version`. Eliminar o cambiar el significado de un campo exige una versión nueva, y los consumidores deben ignorar los campos que no conozcan.