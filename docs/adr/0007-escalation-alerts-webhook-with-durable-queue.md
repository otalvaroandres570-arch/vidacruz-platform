# ADR 0007: Alertas de escalamiento por webhook con cola durable

## Estado
Aceptada

## Contexto
RF-06 exige alertar al equipo médico cuando un paciente es escalado, sin fijar canal, formato ni tecnología.
Se evaluaron canal, entrega fiable, formato y privacidad.

## Alternativas de canal
1. Webhook HTTP (Teams, Slack u otra herramienta de chat): llega donde ya está el equipo.
2. Correo (SMTP): universal, pero lento para una urgencia y obliga a operar un servidor de correo.
3. Flujo en vivo (SSE o WebSocket) para un panel: inmediato, pero solo lo ve quien lo tiene abierto.
4. Otro topic de Kafka: desacoplado, pero no llega a una persona sin un consumidor adicional.

## Decisión
- Canal: webhook HTTP genérico. El mensaje lleva `text` (lo que muestran Slack y herramientas parecidas) y un
  objeto `alert` estructurado, de modo que se puede adaptar a Teams con un flujo de Power Automate.
- Entrega fiable: la alerta se guarda en la tabla `escalation_alert` en la misma transacción que el escalamiento,
  su auditoría y su evento. Una clave primaria por paciente garantiza una alerta por escalamiento (RN-03).
- Un despachador periódico (cada 5 s) reserva las alertas pendientes con `FOR UPDATE SKIP LOCKED` y un plazo de
  reserva, de modo que con varias réplicas cada alerta la envía una sola. Un fallo programa un reintento con espera
  exponencial (5 s, 10 s, 20 s... máximo 5 min) y se reintenta indefinidamente.
- Sin URL configurada, el canal es el log (registro `escalation-alerts`), así que el servicio funciona sin configurar nada.

## Supuestos
- El mensaje contiene solo el id del paciente, el nivel, el SLA y la espera. No incluye nombre, signos vitales ni
  queja principal, porque sale hacia una herramienta externa.
- La URL del webhook es un secreto: se lee de una variable de entorno (en Kubernetes, un Secret) y nunca se escribe
  en logs, errores ni base de datos.
- Una alerta no se descarta nunca: un aviso médico perdido en silencio es peor que uno repetido o tardío.

## Consecuencias
- Un canal caído no afecta al escalamiento ni al triaje. Las alertas se entregan al recuperarse.
- Entrega al menos una vez: si el canal acepta el mensaje pero falla el marcado como enviado, se reenvía.
- Cambiar de canal es sustituir un adaptador (puerto `AlertNotifier`), sin tocar el dominio.
- Una alerta bloqueada de forma permanente seguiría reintentándose cada 5 min: se vigila con los logs
  y, en la Épica 7, con una métrica de alertas pendientes.