# Integração Datadog — Observabilidade

## Visão Geral

A aplicação Garage possui integração completa com o Datadog cobrindo os quatro pilares de observabilidade:

| Pilar | Tecnologia | Transporte |
|-------|-----------|------------|
| Métricas | Micrometer + StatsD | UDP → Datadog Agent (porta 8125) |
| Tracing (APM) | dd-java-agent | TCP → Datadog Agent (porta 8126) |
| Logs | LogstashEncoder (JSON) | stdout → Datadog Agent (log collector) |
| Infraestrutura | Kubelet integration | Datadog Agent → Datadog API |

## O que foi implementado

### 1. Métricas da Aplicação

**Dependência:** `micrometer-registry-statsd` (versão gerenciada pelo Spring Boot BOM)

**Configuração** (`application.yml`):
- Exportação StatsD para `${DD_AGENT_HOST:localhost}:8125` com flavor `datadog`
- Tags globais (Unified Service Tagging): `env`, `service`, `version`
- Percentis p50/p90/p95/p99 para `http.server.requests`
- SLOs com buckets de histograma: 100ms, 250ms, 500ms, 1000ms

**Métricas customizadas de Ordens de Serviço** (`ServiceOrderMetrics`):

| Métrica | Tipo | Tags |
|---------|------|------|
| `garage.service_order.created.count` | Counter | `status` |
| `garage.service_order.status_change.count` | Counter | `from_status`, `to_status` |
| `garage.service_order.processing.duration` | Timer | `operation`, `status` |
| `garage.service_order.error.count` | Counter | `operation`, `exception_class` |
| `garage.service_order.active.count` | Gauge | — |

As métricas são registradas em todos os services de ordem de serviço (create, start_diagnosis, finish_diagnosis, complete, deliver, cancel, start_execution, finish_execution). Exceções nas métricas são capturadas internamente e nunca propagam para a camada de negócio.

### 2. Tracing Distribuído (APM)

O `dd-java-agent.jar` é baixado durante o build da imagem Docker e injetado via `-javaagent` no CMD do container. Isso habilita:
- Tracing automático de todas as requisições HTTP
- Injeção de `dd.trace_id` e `dd.span_id` no MDC do Logback
- Correlação automática entre traces e logs no Datadog

### 3. Logs Estruturados

**Formato:** JSON via LogstashEncoder (perfil `prod`)

**Campos MDC incluídos nos logs:**
- `dd.trace_id`, `dd.span_id`, `dd.service`, `dd.env`, `dd.version` (injetados pelo dd-java-agent)
- `correlationId`, `httpMethod`, `requestUri` (injetados pelo `CorrelationFilter`)
- `userId`, `service_order_id`, `service_order_status`, `operation` (injetados pelo código de negócio)

O `CorrelationFilter` gera/propaga o header `X-Correlation-ID` e adiciona ao MDC sem sobrescrever os campos do Datadog.

### 4. Endpoints do Actuator

Endpoints expostos: `health`, `info`, `metrics`, `prometheus`

Acesso não autenticado configurado no `SecurityConfig` para:
- `/actuator/health`
- `/actuator/info`
- `/actuator/metrics`

### 5. Kubernetes — Deployment

Labels de Unified Service Tagging no pod template:
```yaml
tags.datadoghq.com/env: "prod"
tags.datadoghq.com/service: "garage"
tags.datadoghq.com/version: "1.0.0"
```

Variáveis de ambiente injetadas via Downward API:
- `DD_AGENT_HOST` → `status.hostIP`
- `DD_ENV`, `DD_SERVICE`, `DD_VERSION` → labels do pod
- `DD_LOGS_INJECTION=true`

Annotation para coleta de logs:
```yaml
ad.datadoghq.com/garage-app.logs: '[{"source":"java","service":"garage"}]'
```

### 6. Monitores (Alertas)

Definições JSON em `datadog/monitors/` (repositório `garage-observability`):

| Arquivo | Tipo | Threshold |
|---------|------|-----------|
| `service-order-error-rate.json` | Taxa de erros em OS | WARN >5%, CRITICAL >15% (5min) |
| `health-check.json` | Healthcheck DOWN | CRITICAL após 2min |
| `api-latency-p95.json` | Latência p95 | WARN >1000ms (5min) |
| `memory-usage.json` | Memória do pod | WARN >80% de 1Gi |
| `cpu-usage.json` | CPU do pod | WARN >80% de 500m |

### 7. Dashboard

Definição JSON em `datadog/dashboard/garage-operations.json` (repositório `garage-observability`) com 7 widgets:
1. Volume diário de OS criadas
2. Tempo médio por fase (Diagnóstico, Execução, Finalização)
3. Contagem de erros por operação
4. Latência p50/p90/p99 das APIs REST
5. Ordens ativas por status
6. Consumo CPU/memória dos pods
7. Uptime percentual 24h/7d

---

## Passos para Deploy

### Pré-requisitos

- Cluster Kubernetes com acesso configurado (`kubectl`)
- Helm 3 instalado
- Conta Datadog com API key
- Acesso ao ECR para push da imagem Docker

### Passo 1: Criar o Secret da API Key do Datadog

```bash
kubectl create namespace datadog

kubectl create secret generic datadog-api-key \
  --from-literal=api-key=<SUA_API_KEY_DATADOG> \
  -n datadog
```

### Passo 2: Instalar o Datadog Agent via Helm

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update

helm install datadog-agent datadog/datadog \
  -f k8s/datadog/values.yaml \
  -n datadog
```

Verificar se o Agent está rodando:
```bash
kubectl get pods -n datadog -l app=datadog
```

### Passo 3: Build e Push da Imagem Docker

```bash
docker build -t garage-app:latest .
docker tag garage-app:latest <ECR_REGISTRY>/garage-app:<IMAGE_TAG>
docker push <ECR_REGISTRY>/garage-app:<IMAGE_TAG>
```

> O Dockerfile já inclui o download do `dd-java-agent.jar` e o `-javaagent` no CMD.

### Passo 4: Atualizar a versão no deployment.yaml

Antes de aplicar, atualize a label `tags.datadoghq.com/version` no `k8s/deployment.yaml` para a versão correta do build:

```yaml
tags.datadoghq.com/version: "<VERSAO_DO_BUILD>"
```

### Passo 5: Aplicar o Deployment

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/configmap.yaml
```

Verificar se os pods estão rodando:
```bash
kubectl get pods -l app=garage-app
kubectl logs -l app=garage-app --tail=50
```

### Passo 6: Criar Monitores no Datadog

Os monitores podem ser criados via API do Datadog ou importados manualmente pelo console.

**Via API:**
```bash
for monitor in datadog/monitors/*.json; do
  curl -X POST "https://api.datadoghq.com/api/v1/monitor" \
    -H "Content-Type: application/json" \
    -H "DD-API-KEY: <SUA_API_KEY>" \
    -H "DD-APPLICATION-KEY: <SUA_APP_KEY>" \
    -d @"$monitor"
done
```

**Via Console:** Importar cada JSON em Monitors → New Monitor → Import.

### Passo 7: Criar Dashboard no Datadog

**Via API:**
```bash
curl -X POST "https://api.datadoghq.com/api/v1/dashboard" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: <SUA_API_KEY>" \
  -H "DD-APPLICATION-KEY: <SUA_APP_KEY>" \
  -d @datadog/dashboard/garage-operations.json
```

**Via Console:** Dashboards → New Dashboard → Import Dashboard JSON.

### Passo 8: Validação

1. **Métricas:** No Datadog, vá em Metrics → Explorer e busque por `garage.service_order.*`
2. **APM:** Em APM → Services, verifique se o serviço `garage` aparece
3. **Logs:** Em Logs → Search, filtre por `service:garage` e verifique os campos `dd.trace_id` e `correlationId`
4. **Infraestrutura:** Em Infrastructure → Kubernetes, verifique os pods da aplicação
5. **Dashboard:** Abra o dashboard "Garage - Operações de Ordens de Serviço"
6. **Monitores:** Em Monitors → Manage Monitors, verifique se os 5 monitores estão ativos

---

## Estrutura de Arquivos

### Repositório `garage-observability` (este repositório)

```
garage-observability/
├── datadog/
│   ├── dashboard/
│   │   └── garage-operations.json                      # Dashboard com 7 widgets
│   └── monitors/
│       ├── service-order-error-rate.json               # Taxa de erros OS
│       ├── health-check.json                           # Healthcheck DOWN
│       ├── api-latency-p95.json                        # Latência p95
│       ├── memory-usage.json                           # Memória >80%
│       └── cpu-usage.json                              # CPU >80%
├── k8s/
│   └── datadog/values.yaml                             # Helm values para Datadog Agent
└── docs/
    └── DATADOG.md                                      # Esta documentação
```

### Repositório `tech-challenge` (código da aplicação)

```
tech-challenge/
├── Dockerfile                                          # dd-java-agent + -javaagent
├── src/main/resources/
│   ├── application.yml                                 # StatsD, Actuator, tags
│   └── logback-spring.xml                              # JSON logs com campos DD
├── src/main/java/.../shared/
│   ├── logging/CorrelationFilter.java                  # X-Correlation-ID → MDC
│   └── metrics/
│       ├── ServiceOrderMetrics.java                    # Interface
│       └── DatadogServiceOrderMetrics.java             # Implementação com Micrometer
└── k8s/
    └── deployment.yaml                                 # Unified Service Tagging + DD vars
```
