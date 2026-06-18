# Guia de migracao do qq-helm v1 para qq-helm-v2

Este guia descreve como converter um `values.yaml` usado no chart v1 para o formato do `qq-helm-v2` e como executar o upgrade de forma segura no cluster.

## Objetivo

Migrar uma aplicacao por vez para o chart separado `qq-helm-v2`, mantendo:

- mesmo release Helm;
- mesmos nomes dos recursos principais;
- mesmo selector `app: <nome>`;
- possibilidade de rollback pelo historico do Helm;
- chart v1 intacto para apps ainda nao migrados.

## Premissas

- O chart v1 continua publicado e usado pelos apps nao migrados.
- O chart v2 deve ser publicado como outro chart:

```bash
oci://harbor.mgm-k8s.qq/library/qq-helm/qq-helm-v2
```

- Nao publicar o v2 no mesmo chart/repo usado pela `main` enquanto pipelines antigos dependerem dele.
- Usar a branch `qq-helm-v2` para desenvolvimento e manutencao do novo chart.

## Conversao do values v1 para v2

### Nome da aplicacao

v1:

```yaml
application_name: negociacao
```

v2:

```yaml
fullnameOverride: negociacao
```

Use `fullnameOverride` para preservar o nome dos recursos e o selector `app: negociacao`.

### Workload

v1:

```yaml
deployment:
  enabled: true

replicas: 1
```

v2:

```yaml
workload:
  enabled: true
  type: Deployment
  replicas: 1
```

Para `StatefulSet`:

```yaml
workload:
  enabled: true
  type: StatefulSet
  replicas: 1
```

Evite trocar `Deployment` por `StatefulSet` no mesmo upgrade de migracao, porque isso pode envolver campos imutaveis e mudanca operacional relevante.

### Imagem

v1:

```yaml
image: harbor.mgm-k8s.qq/projeto/app:$VERSION.$COMMIT_HASH
imagePullSecrets:
  name: harbor-secret
imagePullPolicy: IfNotPresent
```

v2:

```yaml
image:
  repository: harbor.mgm-k8s.qq/projeto/app
  tag: $VERSION.$COMMIT_HASH
  pullPolicy: IfNotPresent
  pullSecrets:
    - name: harbor-secret
```

### Labels

v1:

```yaml
labels:
  tags.datadoghq.com/env: hml
  tags.datadoghq.com/service: negociacao
  tags.datadoghq.com/version: $VERSION
```

v2:

```yaml
labels:
  tags.datadoghq.com/env: hml
  tags.datadoghq.com/service: negociacao
  tags.datadoghq.com/version: $VERSION
```

Labels continuam no mesmo bloco. O chart tambem adiciona labels padrao do Helm.

### Command e args

v1:

```yaml
command: ["npm"]
args: ["run", "start:hml"]
```

v2:

```yaml
container:
  command:
    - npm
  args:
    - run
    - start:hml
```

### Portas do container

v1 usava a porta do service como referencia:

```yaml
service:
  port: 3190
  targetPort: 3190
```

v2 explicita a porta no container:

```yaml
container:
  ports:
    - name: http
      containerPort: 3190
      protocol: TCP
```

### Env simples

v1:

```yaml
envVars:
  LOG_LEVEL: "debug"
  METRICS: "true"
```

v2:

```yaml
container:
  env:
    plain:
      LOG_LEVEL: debug
      METRICS: "true"
```

### Env via Downward API ou valueFrom

v1:

```yaml
envVarsRef:
  DD_AGENT_HOST:
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
```

v2:

```yaml
container:
  env:
    valueFrom:
      - name: DD_AGENT_HOST
        valueFrom:
          fieldRef:
            fieldPath: status.hostIP
```

Outros metadados comuns:

```yaml
container:
  env:
    valueFrom:
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: POD_NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: POD_IP
        valueFrom:
          fieldRef:
            fieldPath: status.podIP
      - name: NODE_NAME
        valueFrom:
          fieldRef:
            fieldPath: spec.nodeName
      - name: NODE_IP
        valueFrom:
          fieldRef:
            fieldPath: status.hostIP
```

### Env vindo de Secret externo

v2 suporta Secret nao criado pelo Helm:

```yaml
container:
  env:
    fromSecrets:
      - name: DATABASE_PASSWORD
        secretName: app-db-secret
        key: password
```

### ConfigMap criado pelo chart

v1:

```yaml
configmap:
  enabled: true
  data:
    CONFIG: config
```

v2:

```yaml
configMaps:
  create: true
  data:
    CONFIG: config
```

### Secret criado pelo chart

v1:

```yaml
secrets:
  enabled: true
  data:
    SECRET: secret
```

v2:

```yaml
secrets:
  create: true
  type: Opaque
  data:
    SECRET: secret
```

Tambem pode usar `stringData`:

```yaml
secrets:
  create: true
  stringData:
    SECRET: secret
```

### Probes

v1:

```yaml
startupProbe:
  enabled: true
  periodSeconds: 10
  failureThreshold: 6
  httpGet:
    enabled: true
    port: 3190
    path: /api/health

livenessProbe:
  enabled: true
  periodSeconds: 60
  initialDelaySeconds: 60
  httpGet:
    enabled: true
    port: 3190
    path: /api/health
```

v2:

```yaml
probes:
  startup:
    enabled: true
    periodSeconds: 10
    failureThreshold: 6
    httpGet:
      port: 3190
      path: /api/health
  liveness:
    enabled: true
    periodSeconds: 60
    initialDelaySeconds: 60
    httpGet:
      port: 3190
      path: /api/health
```

### Resources

v1 e v2 usam a mesma estrutura:

```yaml
resources:
  requests:
    cpu: 10m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

### Scheduling

v1:

```yaml
tolerations:
  key: node_group
  value: application-private
  effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      key: node_group
      values: application-private
```

v2 usa estrutura Kubernetes nativa:

```yaml
scheduling:
  tolerations:
    - key: node_group
      operator: Equal
      value: application-private
      effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node_group
                operator: In
                values:
                  - application-private
```

### PVC

v1:

```yaml
persistence:
  enabled: true
  pvcName: negociacao-pvc
  requestSize: 512Mi
  limitSize: 1Gi
  accessMode: ReadWriteMany
  storageClass: longhorn-local

volumes:
  - name: temp
    dir: /home/node/temp
    pvcName: negociacao-pvc
```

v2 criando PVC:

```yaml
volumes:
  pvc:
    create: true
    claims:
      - name: negociacao-pvc
        size: 512Mi
        accessModes:
          - ReadWriteMany
        storageClassName: longhorn-local
        mountPath: /home/node/temp
```

v2 usando PVC existente:

```yaml
volumes:
  pvc:
    create: false
    claims:
      - name: temp
        claimName: negociacao-pvc
        mountPath: /home/node/temp
```

Para migracao segura, se o PVC ja existe e deve ser preservado, prefira `create: false` e informe `claimName`.

### Secret externo como volume

```yaml
volumes:
  existing:
    - name: app-certificates
      type: secret
      secretName: app-tls-secret
      mountPath: /etc/tls
      readOnly: true
```

### HPA

v1:

```yaml
hpa:
  enabled: true
  min: 1
  max: 2
  cpuAverageUtilization: 2500
```

v2:

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 2
  targetCPUUtilizationPercentage: 2500
```

O chart v2 aponta o HPA para `Deployment` ou `StatefulSet` conforme `workload.type`.

### Service

v1:

```yaml
service:
  enabled: true
  type: ClusterIP
  protocol: TCP
  port: 3190
  targetPort: 3190
```

v2:

```yaml
service:
  enabled: true
  type: ClusterIP
  ports:
    - name: http
      port: 3190
      targetPort: http
      protocol: TCP
```

No v2, o Ingress deve apontar para a porta do Service, por nome ou numero. Prefira `http`.

### Ingress

v1:

```yaml
ingress:
  enabled: true
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  dns: negociacao.app.hml-k8s.qq
  tls: true
  caIssuer: ca-issuer-qq
  paths:
    - path: /api
      pathType: Prefix
```

v2:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    cert-manager.io/cluster-issuer: ca-issuer-qq
    cert-manager.io/common-name: negociacao.app.hml-k8s.qq
  hosts:
    - host: negociacao.app.hml-k8s.qq
      paths:
        - path: /api
          pathType: Prefix
          servicePort: http
  tls:
    - hosts:
        - negociacao.app.hml-k8s.qq
      secretName: negociacao.app.hml-k8s.qq-tls
```

### Metrics / ServiceMonitor

v1:

```yaml
metrics:
  enabled: true
  path: /metrics
  interval: 30s
  scrapeTimeout: 10s
```

v2:

```yaml
serviceMonitor:
  enabled: true
  labels:
    release: rancher-monitoring
  path: /metrics
  interval: 30s
  scrapeTimeout: 10s
```

## Validacao local antes do upgrade

Na branch `qq-helm-v2`, execute:

```bash
helm lint .
helm template test . --values values.yaml
helm template test . --values examples/values-v1.yaml
helm template test . --values examples/values-v2.yaml
helm template test . --values examples/external-secret.yaml
```

Para validar um app migrado:

```bash
helm template negociacao . --values examples/negociacao-values-v2.yaml
```

Confira no manifest renderizado:

- `metadata.name` dos recursos principais continua igual ao v1;
- `selector.matchLabels.app` continua igual;
- `Service` continua com o mesmo nome;
- `Deployment` ou `StatefulSet` continua com o mesmo nome;
- `ConfigMap`, `Secret` e PVC continuam com nomes esperados;
- `Ingress` aponta para a porta do Service;
- `HPA` aponta para o tipo correto de workload;
- envs de Secret externo e volumes externos renderizam corretamente.

## Checklist antes de instalar no cluster

1. Confirmar que o app piloto tem `values-v2.yml` revisado.
2. Confirmar que o release atual existe:

```bash
helm history negociacao -n qqpag-svc-hml
```

3. Renderizar localmente o chart v2:

```bash
helm template negociacao . --values values-v2.yml
```

4. Comparar nomes e selectors contra o release atual:

```bash
helm get manifest negociacao -n qqpag-svc-hml > /tmp/negociacao-v1.yaml
helm template negociacao . --values values-v2.yml > /tmp/negociacao-v2.yaml
```

5. Nao prosseguir se houver mudanca em campos sensiveis:

- selector do workload;
- tipo do workload sem planejamento;
- nome do Service;
- nome do Deployment ou StatefulSet;
- nome de PVC;
- `serviceName` de StatefulSet.

## Upgrade seguro para v2

Use o mesmo release Helm e o chart novo:

```bash
helm upgrade negociacao \
  -n qqpag-svc-hml \
  --values values-v2.yml \
  oci://harbor.mgm-k8s.qq/library/qq-helm/qq-helm-v2 \
  --version 2.0.1 \
  --atomic \
  --timeout 5m \
  --insecure-skip-tls-verify
```

Use `--atomic` para rollback automatico caso o upgrade falhe.

## Validacao apos upgrade

Ver historico:

```bash
helm history negociacao -n qqpag-svc-hml
```

Ver status:

```bash
helm status negociacao -n qqpag-svc-hml
```

Checar workloads:

```bash
kubectl get deploy,statefulset,po,svc,ingress,hpa -n qqpag-svc-hml -l app=negociacao
```

Checar rollout:

```bash
kubectl rollout status deployment/negociacao -n qqpag-svc-hml --timeout=5m
```

Para StatefulSet:

```bash
kubectl rollout status statefulset/negociacao -n qqpag-svc-hml --timeout=5m
```

Checar eventos se houver falha:

```bash
kubectl get events -n qqpag-svc-hml --sort-by=.lastTimestamp
```

## Rollback manual

Se precisar voltar para a revisao anterior:

```bash
helm history negociacao -n qqpag-svc-hml
helm rollback negociacao <REVISAO_ANTERIOR> -n qqpag-svc-hml
```

Depois valide:

```bash
helm status negociacao -n qqpag-svc-hml
kubectl rollout status deployment/negociacao -n qqpag-svc-hml --timeout=5m
```

## Regras praticas de migracao

- Migrar um app por vez.
- Comecar por app piloto em homologacao.
- Nao alterar workload type durante a migracao, salvo se for uma mudanca planejada separadamente.
- Nao renomear recursos no primeiro upgrade para v2.
- Nao trocar selector no primeiro upgrade para v2.
- Nao recriar PVC existente por acidente.
- Usar `--atomic` em migracoes.
- Manter v1 publicado ate a migracao total.
- Publicar o v2 como `qq-helm-v2`, separado do `qq-helm`.

## Exemplos no repositorio

- `examples/values-v1.yaml`: exemplo usando campos v1.
- `examples/values-v2.yaml`: exemplo usando estrutura v2.
- `examples/external-secret.yaml`: exemplo de Secret externo como env e volume.
- `examples/negociacao-values-v2.yaml`: exemplo convertido de um app real.
