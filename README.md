# qq-helm-v2

Chart Helm v2 da Quero-Quero, publicado como chart separado para migracao app por app.

## Harbor OCI

```bash
helm upgrade --install :release \
  -n :namespace \
  --values values-v2.yml \
  oci://harbor.mgm-k8s.qq/library/qq-helm/qq-helm-v2 \
  --version 2.0.1 \
  --atomic \
  --timeout 5m \
  --insecure-skip-tls-verify
```

## GitHub Helm Repo

Use somente se houver repositorio/URL separado para v2, sem atualizar o `index.yaml` da `main` usada pelo v1.

```bash
helm repo add qq-helm-v2 :url-do-repo-v2
helm upgrade --install :release -n :namespace --values values-v2.yml qq-helm-v2/qq-helm-v2
```

## Compatibilidade v1

O chart aceita campos v1 durante a transicao quando fizer sentido. Valores novos tem prioridade sobre os antigos.

Principais mapeamentos:

- `application_name` preserva o nome dos recursos e o selector `app`.
- `deployment.enabled` e `statefulSet.enabled` definem o tipo de workload quando `workload.type` nao for informado.
- `envVars`, `envVarsRef`, `configmap`, `secrets`, `persistence`, `volumes`, `hpa` e `metrics` continuam aceitos.

## Secret externo como env

```yaml
container:
  env:
    fromSecrets:
      - name: DATABASE_PASSWORD
        secretName: app-db-secret
        key: password
```

## Secret externo como volume

```yaml
volumes:
  existing:
    - name: app-certificates
      type: secret
      secretName: app-tls-secret
      mountPath: /etc/tls
      readOnly: true
```

## Testes locais

```bash
helm lint .
helm template test . --values values.yaml
helm template test . --values examples/values-v1.yaml
helm template test . --values examples/values-v2.yaml
helm template test . --values examples/external-secret.yaml
```
