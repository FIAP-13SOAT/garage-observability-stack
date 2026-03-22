# Garage Observability Stack

Stack de observabilidade da aplicacao **Garage**, provisionada via **Terraform** sobre um cluster **Amazon EKS** com integracao completa ao **Datadog**.

## O que este repositorio provisiona

- **Datadog Agent** no cluster EKS via Helm (APM, metricas, logs e infra)
- **5 Monitores (alertas)** no Datadog:
  - Taxa de erros em Ordens de Servico (warn >5%, critical >15%)
  - Health Check DOWN (critical apos 2 checks consecutivos)
  - Latencia P95 das APIs (warn >1s, critical >2s)
  - Uso de memoria dos pods (warn >80%, critical >95% de 1Gi)
  - Uso de CPU dos pods (warn >80%, critical >95% de 500m)
- **Dashboard operacional** com 7 widgets (volume de OS, latencia, erros, status, recursos K8s, uptime)

## Estrutura

```
.
├── main.tf                  # Providers (AWS, Datadog, Helm, Kubernetes) e backend S3
├── variables.tf             # Variaveis (datadog_api_key, datadog_app_key, environment)
├── datadog_helm.tf          # Namespace, Secret e Helm release do Datadog Agent
├── datadog_monitors.tf      # 5 monitores de alerta
├── datadog_dashboard.tf     # Dashboard JSON
├── outputs.tf               # Outputs (status do agent, IDs dos monitores, URL do dashboard)
├── k8s/
│   └── datadog/values.yaml  # Helm values para o Datadog Agent
├── datadog/
│   ├── dashboard/
│   │   └── garage-operations.json
│   └── monitors/
│       ├── api-latency-p95.json
│       ├── cpu-usage.json
│       ├── health-check.json
│       ├── memory-usage.json
│       └── service-order-error-rate.json
└── docs/
    └── DATADOG.md           # Documentacao detalhada da integracao
```

## Pre-requisitos

- [Terraform](https://www.terraform.io/) >= 1.0
- AWS CLI configurado com acesso ao cluster EKS (`garage-cluster`)
- Conta Datadog com **API Key** e **App Key**
- Bucket S3 `garage-terraform-state-450059198767` para o backend remoto

## Como rodar

### 1. Configurar as variaveis

Crie um arquivo `terraform.tfvars`:

```hcl
datadog_api_key = "SUA_API_KEY"
datadog_app_key = "SUA_APP_KEY"
environment     = "prod"
```

Ou exporte como variaveis de ambiente:

```bash
export TF_VAR_datadog_api_key="SUA_API_KEY"
export TF_VAR_datadog_app_key="SUA_APP_KEY"
```

### 2. Inicializar o Terraform

```bash
terraform init
```

### 3. Verificar o plano de execucao

```bash
terraform plan
```

### 4. Aplicar a infraestrutura

```bash
terraform apply
```

Isso ira:
- Criar o namespace `datadog` no cluster EKS
- Criar o Secret com a API Key
- Instalar o Datadog Agent via Helm
- Criar os 5 monitores no Datadog
- Criar o dashboard operacional

### 5. Validar

```bash
# Verificar se o Agent esta rodando
kubectl get pods -n datadog

# Ver os outputs do Terraform
terraform output
```

No Datadog:
- **Metrics Explorer**: busque por `garage.service_order.*`
- **APM > Services**: verifique o servico `garage`
- **Monitors > Manage Monitors**: confirme os 5 monitores ativos
- **Dashboards**: abra "Garage - Operacoes de Ordens de Servico"

## Destruir a stack

```bash
terraform destroy
```

## Documentacao adicional

Consulte [docs/DATADOG.md](docs/DATADOG.md) para detalhes sobre metricas customizadas, tracing, logs estruturados e a integracao completa com a aplicacao Garage.
