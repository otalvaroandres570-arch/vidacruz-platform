# ADR 0008: Autenticación por API key

## Estado
Aceptada

## Contexto
El enunciado exige autenticación básica en los endpoints (JWT o API key), sin credenciales en el código y con
validación de entradas. Los clientes de ambos servicios son sistemas internos (no hay usuarios finales ni roles).

## Alternativas
1. JWT con Spring Security (OAuth2 resource server): estándar, con identidad y roles, pero exige un emisor de tokens
   y claves públicas, sin que haya usuarios que lo justifiquen.
2. mTLS: fuerte, pero complica el despliegue y las pruebas.
3. API key compartida por servicio, validada por un filtro propio.

## Decisión
API key en la cabecera `X-API-Key` (alternativa 3), con un filtro de WebFlux sin dependencias nuevas.
- Seguro por defecto: sin una clave de 16 o más caracteres el servicio no arranca.
- Se aceptan varias claves a la vez para rotarlas sin cortes (separadas por comas).
- La comparación se hace sobre huellas SHA-256, recorriendo todas las claves, para no filtrar información por tiempos.
- Públicos solo los probes de salud (`/actuator/health/**`) y `/actuator/info`. El resto exige la clave.
- Las claves se leen solo de variables de entorno (en Kubernetes, de un Secret). Nunca se escriben en logs, errores
  ni respuestas, y el 401 no distingue entre clave ausente y clave incorrecta.
- Los servicios no se llaman entre sí (se comunican por Kafka), así que cada uno tiene su propia clave.

## Consecuencias
- Simple y fácil de operar, pero la clave identifica al sistema cliente y no a una persona: no hay trazabilidad por
  usuario ni permisos por rol.
- Una clave filtrada da acceso total hasta que se rote, por eso la rotación es parte del diseño.
- Si aparecen usuarios o roles, la evolución natural es Spring Security con JWT, y el filtro se sustituye por esa configuración.
- La autenticación puede desactivarse con `enabled=false` solo para los tests automáticos; el servicio lo avisa con un WARN.