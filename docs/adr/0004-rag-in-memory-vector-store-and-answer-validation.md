# ADR 0004: RAG con vector store en memoria y validación de citas

## Estado
Aceptada

## Contexto
El asistente debe responder solo con los protocolos del corpus, citar la fuente y no inventar contenido clínico
(RN-05). El corpus mínimo son 3 protocolos (7 secciones), en español. El proveedor disponible es Gemini (key
gratuita de AI Studio).

## Alternativas
1. pgvector o Redis como vector store: añade infraestructura y persistencia que un corpus de 7 fragmentos no justifica.
2. Búsqueda léxica propia: sin dependencias, pero peor con sinónimos ("antibiótico" frente a "antimicrobiano").
3. Vector store en memoria (SimpleVectorStore de Spring AI) con embeddings multilingües de Gemini.

## Decisión
Alternativa 3. Los embeddings se calculan en la primera consulta, no al arrancar, para que el servicio arranque
aunque Gemini no responda (modo degradado). La relevancia se decide con un umbral de similitud (0.65) calibrado con
mediciones reales: las preguntas con protocolo puntuaron 0.72 o más y las que no, 0.59 o menos. La salida del LLM no
se confía: es un borrador que se valida.

## Doble barrera anti-alucinación
1. Si ningún fragmento supera el umbral, no se consulta al LLM y la respuesta es solo el aviso "no existe protocolo".
2. Si hay fragmentos, el LLM recibe solo ese contexto y debe declarar si puede responder y qué secciones usó. Una
   respuesta sin texto, sin citas o con alguna cita que no esté en el contexto entregado y en el corpus se descarta
   y se sustituye por el aviso. El contenido generado nunca llega al médico sin haber pasado la validación.

## Consecuencias
- El corpus se reconstruye en cada arranque (unos segundos y 7 llamadas de embeddings); con un corpus mayor habría que persistirlo.
- La similitud mide cercanía de tema, no si el protocolo responde: por eso existe la segunda barrera.
- Un cambio de modelo de embeddings obliga a recalibrar el umbral.
- Una respuesta correcta puede descartarse si el modelo escribe una cita con otra grafía; se vigila con la métrica de consultas por resultado.