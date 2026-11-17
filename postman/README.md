# Colección de Postman

| Archivo | Contenido |
|---|---|
| `VidaCruz.postman_collection.json` | Las peticiones y los tests, agrupados por requisito |
| `VidaCruz-local.postman_environment.json` | Variables del entorno local. **Las API keys van vacías** |

## Uso

1. Postman → *Import* → selecciona los dos archivos.
2. Selecciona el entorno `VidaCruz local` (arriba a la derecha) y rellena `triageKey` y `assistantKey` con las claves del `.env` de la plataforma (`TRIAGE_SECURITY_APIKEYS` y `ASSISTANT_SECURITY_APIKEYS`).
3. Con el stack levantado (`run.ps1` o `run.sh`): clic derecho en la colección → *Run collection*.

Para ver el escalamiento (carpeta 6), arranca el triaje con `TRIAGE_SLA_CRITICO=1` y `TRIAGE_SLAMONITOR_INTERVAL=2s` y pon `runEscalation` en `true`.

## Desde la línea de comandos (Newman)

```powershell
npm install -g newman
newman run postman/VidaCruz.postman_collection.json -e postman/VidaCruz-local.postman_environment.json --env-var "triageKey=<clave del triaje>" --env-var "assistantKey=<clave del asistente>"
```
