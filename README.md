### Adicionar Repositório
`` helm repo add qq-helm https://raw.githubusercontent.com/verdecard/qq-helm/main``

### Listar repositorios
`` helm search repo qq-helm/qq-helm ``

### Criando arquivo de values com base no exemplo
`` heml show values > values.yaml ``

### Testando Geracao dos Manifestos (dry-run)
- Antes de executar valide o ambiente que seu kubectl esta apontando para o local correto `` kubectl config get-contexts ``
- se for caso pode mudar com o comando `` kubectl config use-context :nome_contexto ``
- Com o comando ``--dry-run`` o heml nao sera instalado, apenas vai printar os manifestos gerados
- `` helm upgrade -i :deployment -n :namespace --values values.yaml qq-helm/qq-helm --dry-run``


### Criando ou Atualizando Instalacao
- Antes de executar valide o ambiente que seu kubectl esta apontando para o local correto `` kubectl config get-contexts `` 
- se for caso pode mudar com o comando `` kubectl config use-context :nome_contexto ``
- `` helm upgrade -i :deployment -n :namespace --values values.yaml qq-helm/qq-helm ``



### Removendo Instalacao
`` helm uninstall :deployment -n :namespace ``
