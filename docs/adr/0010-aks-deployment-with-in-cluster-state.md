# ADR 0010: Despliegue en AKS con el estado dentro del clúster

## Estado
Aceptada. Pendiente de ejecutar: no se pudo crear la suscripción de Azure (ver la nota al final).

## Contexto
El enunciado pide manifests de Kubernetes con Azure como objetivo (AKS o Azure Container Apps) y una URL pública.
Los servicios dependen de PostgreSQL, Kafka y Redis. Es una entrega de evaluación, con presupuesto limitado.

## Alternativas
1. Azure Container Apps: más simple de operar y con escalado a cero, pero no usa manifests de Kubernetes.
2. AKS con servicios administrados (Azure Database for PostgreSQL, Event Hubs, Azure Cache for Redis): lo adecuado
   para producción, pero más coste y configuración. Event Hubs obliga a soportar SASL en los clientes Kafka.
3. AKS con PostgreSQL, Kafka y Redis dentro del clúster.

## Decisión
Alternativa 3 sobre AKS en la capa Free (el plano de control no se cobra; se paga la máquina del nodo, los discos y
las IP públicas). PostgreSQL y Kafka son StatefulSet con disco de 5 GB; Redis es un Deployment sin disco porque la
vista de urgencias se puede reconstruir desde Kafka. Cada API se expone con un Service de tipo LoadBalancer, sin
depender del add-on de Ingress NGINX (cuyo soporte de parches de seguridad está acotado a noviembre de 2026).
Los secretos (contraseña de PostgreSQL, API keys, key de Gemini, URL del webhook) viven en un Secret de Kubernetes
creado fuera del repositorio. Los contenedores corren como usuario sin privilegios, sin capacidades de Linux y con
perfil seccomp por defecto. Las imágenes se publicarían en Azure Container Registry.

## Consecuencias
- Cero cambios de código y el menor coste; todo se borra con un solo comando.
- Sin TLS (no hay dominio): la API key viaja sin cifrar. Para producción hace falta una puerta de entrada con
  certificado, o Front Door, y rotar las claves tras la evaluación.
- Un solo nodo y una réplica por servicio: sin alta disponibilidad. Escalar es subir réplicas; la idempotencia del
  escalamiento, de las alertas y de la vista de urgencias ya está diseñada para varias.
- Operar Kafka y PostgreSQL uno mismo implica copias de seguridad, actualizaciones y monitorización que un servicio
  administrado resolvería. Para producción, migrar PostgreSQL y Redis es cambio de configuración; Kafka exigiría añadir SASL/TLS al cliente.

## Nota sobre el estado (noviembre de 2026)
No se pudo crear una suscripción de Azure: el alta devuelve "You're not eligible for an Azure free account" y la
solicitud a soporte sigue pendiente. Por eso el despliegue en AKS no se ha ejecutado. Los manifests de `k8s/` están
preparados para aplicarse en cuanto exista la suscripción.
## Lecciones de la prueba en Kubernetes local
Los manifests se probaron en el Kubernetes integrado de Docker Desktop (un nodo). Se encontraron y corrigieron dos problemas que Docker Compose no tenía:
- **Variables de entorno inyectadas por Kubernetes.** Para cada Service con IP, Kubernetes inyecta en todos los pods del espacio de nombres variables como
  `REDIS_PORT=tcp://10.x.x.x:6379`. Chocaban con la propiedad `${REDIS_PORT:6379}` del asistente, que no podía convertir ese texto en un número y se negaba
  a arrancar (`CrashLoopBackOff`). Se resolvió con `enableServiceLinks: false` en todos los pods: los servicios se encuentran por nombre DNS, así que no hacen falta.
- **Los Job son inmutables.** Cambiar la plantilla de `kafka-init` exige borrarlo y aplicarlo de nuevo. Es seguro: su único trabajo es verificar que el topic existe.

También se comprobó que los discos de PostgreSQL y de Kafka se montan en una subcarpeta (por la carpeta `lost+found` de los discos recién formateados), que Kafka funciona con un
Service sin IP propia que publica también las direcciones aún no listas, y que los Secret se crean con `--from-literal` para evitar que los saltos de línea de Windows se cuelen en las claves.