# Creates or completes .env with random secrets, starts everything and waits until both services are ready.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function New-Secret {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) { New-Item -ItemType File -Path $envFile | Out-Null }

$content = Get-Content $envFile -Raw
if ($content -and -not $content.EndsWith("`n")) { Add-Content -Path $envFile -Value "" }

# Adds a variable only if .env does not define it yet: existing values are never touched
function Ensure-Var($name, $value) {
    if ($content -notmatch "(?m)^$name=.+") {
        Add-Content -Path $envFile -Value "$name=$value"
        Write-Host "  added $name to .env"
    }
}

Ensure-Var "POSTGRES_DB" "triage_db"
Ensure-Var "POSTGRES_USER" "triage_user"
Ensure-Var "POSTGRES_PASSWORD" (New-Secret)
Ensure-Var "TRIAGE_SECURITY_APIKEYS" (New-Secret)
Ensure-Var "ASSISTANT_SECURITY_APIKEYS" (New-Secret)
if ($env:GEMINI_API_KEY) { Ensure-Var "GEMINI_API_KEY" $env:GEMINI_API_KEY }

# docker compose gives shell variables priority over .env, so values left over in this session
# (for example API keys exported earlier for bootRun) would silently replace the ones in .env.
"POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD", "TRIAGE_SECURITY_APIKEYS", "ASSISTANT_SECURITY_APIKEYS",
"GEMINI_API_KEY", "GEMINI_CHAT_MODEL", "TRIAGE_ALERTS_WEBHOOK_URL" |
    ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }

# docker compose gives shell variables priority over .env, so values left over in this session
# (for example API keys exported earlier for bootRun) would silently replace the ones in .env.
"POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD", "TRIAGE_SECURITY_APIKEYS", "ASSISTANT_SECURITY_APIKEYS",
"GEMINI_API_KEY", "GEMINI_CHAT_MODEL", "TRIAGE_ALERTS_WEBHOOK_URL" |
    ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }

docker compose up --build -d
if ($LASTEXITCODE -ne 0) { throw "docker compose failed" }

Write-Host "Waiting for the services..."
$ready = $false
foreach ($attempt in 1..60) {
    try {
        $triage = (Invoke-RestMethod "http://localhost:8081/actuator/health/readiness").status
        $assistant = (Invoke-RestMethod "http://localhost:8082/actuator/health/readiness").status
        if ($triage -eq "UP" -and $assistant -eq "UP") { $ready = $true; break }
    } catch { }
    Start-Sleep -Seconds 5
}

if ($ready) {
    Write-Host "Ready: triage http://localhost:8081  |  assistant http://localhost:8082"
    Write-Host "The API keys are in .env (TRIAGE_SECURITY_APIKEYS / ASSISTANT_SECURITY_APIKEYS), sent in the X-API-Key header."
} else {
    Write-Host "The services did not become ready in time. Check: docker compose ps  and  docker compose logs"
}


