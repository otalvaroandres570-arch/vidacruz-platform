# ADR 0005: Modo degradado con circuit breaker y tiempo máximo

## Estado
Aceptada

## Contexto
El asistente depende de un proveedor externo (Gemini) para los embeddings y la generación. Su caída, lentitud o
agotamiento de cuota no debe colgar las peticiones ni afectar al servicio de triaje.

## Decisión
- Un circuit breaker de Resilience4j (ventana de 10 llamadas, abre con el 50 % de fallos tras 5 llamadas, 30 s abierto)
  protege las dos llamadas al proveedor, que comparten clave y cuota. Un tiempo máximo de 20 s dentro del circuito
  hace que un proveedor lento cuente como fallo.
- Los reintentos internos de Spring AI se reducen a 2 para no sumar esperas largas.
- Cualquier fallo técnico (proveedor, circuito abierto, respuesta ilegible) llega al cliente como 503
  `ASSISTANT_UNAVAILABLE` con un mensaje claro. Con el circuito abierto la llamada se rechaza sin tocar al proveedor.
- Resilience4j se configura de forma programática, sin su starter de Spring Boot.

## Consecuencias
- El triaje nunca depende del asistente: se comunican solo por Kafka, y el asistente puede estar caído sin efecto.
- "No existe protocolo" no es un fallo: responde 200 con el aviso y sin fuentes.
- Un solo circuito para embeddings y generación: si uno falla, el otro también se bloquea (el proveedor es el mismo).
- La llamada bloqueante del cliente de Gemini puede seguir ocupando un hilo del planificador tras agotarse el tiempo.