# Release do Chart

Passo a passo para gerar nova versao do chart e publicar no Harbor.

## 1. Atualizar versao

Atualize a versao no `Chart.yaml`:

```yaml
version: 2.0.1
```

Se necessario, atualize tambem o `appVersion`.

## 2. Gerar pacote

```bash
helm package . --version 2.0.1
```

Isso gera o arquivo:

```bash
qq-helm-v2-2.0.1.tgz
```

## 3. Login no Harbor

```bash
helm registry login harbor.mgm-k8s.qq
```

Se precisar informar usuario explicitamente:

```bash
helm registry login harbor.mgm-k8s.qq -u <usuario>
```

## 4. Upload para o Harbor

O destino deve ser o repositorio pai. Nao repetir o nome do chart no final.

```bash
helm push qq-helm-v2-2.0.1.tgz oci://harbor.mgm-k8s.qq/library/qq-helm
```

Resultado esperado:

```bash
Pushed: harbor.mgm-k8s.qq/library/qq-helm/qq-helm-v2:2.0.1
Digest: sha256:<digest>
```

## 5. Validar publicacao

```bash
helm pull oci://harbor.mgm-k8s.qq/library/qq-helm/qq-helm-v2 --version 2.0.1
```

Se o pull funcionar, chart publicado corretamente.

## 6. Commit das atualizacoes

```bash
git status
git add Chart.yaml qq-helm-v2-2.0.1.tgz RELEASE.md
git commit -m "[Release - 2.0.1]" -m "Publica chart qq-helm-v2 no Harbor"
git push origin qq-heml-v2
```

## Observacoes

- Para OCI/Harbor, `helm repo index .` nao e necessario.
- Se aparecer `not found` no pull, confirme se o `helm push` foi feito para `oci://harbor.mgm-k8s.qq/library/qq-helm`.
- O nome final do artefato vem do `name` no `Chart.yaml`.
