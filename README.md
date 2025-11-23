# FCG IaC Terraform

Este repositório contém a infraestrutura como código (IaC) para provisionamento de recursos AWS utilizando Terraform, incluindo OpenSearch, IAM, ECR, S3, EKS, CodeBuild e CodePipeline.

## Arquitetura
Esta arquitetura utiliza um **API Gateway** para integrar os microsserviços de **Jogos**, **Catálogos** e **Pagamentos**, além do **Keycloak** para autenticação. Cada microsserviço acessa seu próprio índice no **OpenSearch**. O microsserviço de Pagamentos processa ordens de forma assíncrona via mensageria (SQS). Todos os microsserviços são implantados em um cluster **EKS** (Kubernetes gerenciado AWS).


O diagrama abaixo ilustra a arquitetura descrita:

![Diagrama de Arquitetura](docs/fcg-architecture-microservices-diagram.drawio.png)


### Repositórios dos Microsserviços

- **Jogos:** [fcg-games-microservice](https://github.com/PauloBusch/fcg-games-microservice)
- **Pagamentos:** [fcg-payment-service](https://github.com/M4theusVieir4/fcg-payment-service)
- **Catálogos:** [fcg-catalog-microservice](https://github.com/marceloalvees/fcg-catalog-microservice)


## Pré-requisitos

- [Terraform](https://www.terraform.io/downloads.html) instalado
- Credenciais AWS configuradas (via AWS CLI ou variáveis de ambiente)


## Como usar

1. Inicialize o Terraform:
   ```powershell
   terraform init
   ```
2. Visualize o plano de execução:
   ```powershell
   terraform plan
   ```
3. Aplique as mudanças:
   ```powershell
   terraform apply
   ```
4. **Para destruir toda a infraestrutura criada:**
   ```powershell
   terraform destroy
   ```

## CI/CD e Deploy no EKS

- O deploy dos microsserviços no EKS é realizado via CodePipeline e CodeBuild.
- O pipeline espera um arquivo de buildspec chamado `ci-pipeline.yml` (ou `buildspec.yml` se configurado assim) na raiz do repositório de cada microsserviço.
- O buildspec deve:
  - Instalar o .NET, Docker e kubectl
  - Fazer login no ECR e construir/push da imagem
  - Atualizar o kubeconfig do EKS (`aws eks update-kubeconfig`)
  - Aplicar os manifests Kubernetes com `kubectl apply -f ...`
- O role do CodeBuild precisa estar mapeado no ConfigMap `aws-auth` do EKS com permissão de admin (`system:masters`). Isso já é feito via Terraform neste repositório.

Exemplo de buildspec (ci-pipeline.yml):
```yaml
version: 0.2
phases:
  install:
    commands:
      - # Instalação de dependências (dotnet, docker, kubectl)
  pre_build:
    commands:
      - aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
  build:
    commands:
      - # Build e push da imagem Docker
  post_build:
    commands:
      - kubectl apply -f k8s/
```

**Importante:**
- O arquivo de buildspec deve estar presente na raiz do repositório do microserviço.
- Se o nome for diferente de `buildspec.yml`, configure o projeto CodeBuild para usar o nome correto.
- O role do CodeBuild precisa estar no grupo `system:masters` do EKS para que `kubectl` funcione.

## Estrutura dos Arquivos

- [`main.tf`](main.tf): Configuração do provider AWS.
- [`variables.tf`](variables.tf): Definição de variáveis globais do projeto.
- [`configuration.tf`](configuration.tf): Configuração dinâmica dos microsserviços (dados de SQS, IAM, ECR, etc.).
- [`network.tf`](network.tf): Provisionamento de VPC, subnets públicas/privadas, Internet Gateway, Route Tables, Security Groups, Load Balancer (ALB) e API Gateway.
- [`iam.tf`](iam.tf): Recursos relacionados a usuários, grupos e permissões IAM, incluindo usuários para OpenSearch e SQS, e roles para CodeBuild, CodePipeline e EKS.
- [`opensearch.tf`](opensearch.tf): Provisionamento do domínio OpenSearch e permissões de acesso.
- [`ecr.tf`](ecr.tf): Provisionamento dos repositórios ECR para imagens dos microsserviços.
- [`s3.tf`](s3.tf): Provisionamento dos buckets S3 para artefatos do CodeBuild.
- [`codebuild.tf`](codebuild.tf): Provisionamento dos projetos CodeBuild, configurados para build/deploy dos microsserviços.
- [`eks.tf`](eks.tf): Provisionamento do cluster EKS, node groups, secrets e config maps para os microsserviços.
- [`sqs.tf`](sqs.tf): Provisionamento das filas SQS para mensageria dos microsserviços.
- [`codepipeline.tf`](codepipeline.tf): Provisionamento do pipeline de CI/CD para build e deploy dos microsserviços no EKS.
- `terraform.tfstate`, `terraform.tfstate.backup`: Arquivos de estado do Terraform.

## Variáveis principais

As variáveis principais estão definidas em [`variables.tf`](variables.tf):

- `aws_region`: Região AWS (padrão: us-east-2)
- `opensearch_domain`: Nome do domínio OpenSearch
- `eks_cluster_name`: Nome do cluster EKS
- `eks_desired_capacity`: Número desejado de nodes no EKS
- `eks_min_size`: Número mínimo de nodes no EKS
- `eks_max_size`: Número máximo de nodes no EKS


## Configuração dos Microsserviços

As configurações dinâmicas dos microsserviços estão definidas em [`configuration.tf`](configuration.tf):

- `microservices_config`: Lista de objetos contendo dados de OpenSearch, GitHub, ECR, S3, etc. para cada microsserviço. Cada campo é utilizado para provisionar recursos específicos via Terraform.
   - Exemplo:
      ```hcl
      microservices_config = [
         {
            key                  = "catalogs"
            opensearch_user      = "fcg-catalogs-opensearch-user"
            github_user          = "marceloalvees"
            github_repository    = "tech-challenge-net-phase-3"
            ecr_repository       = "fcg-ecr-catalogs-repository"
            s3_bucket            = "fcg-s3-catalogs-bucket"
         }
      ]
      ```

- `microservices_sqs_config`: Lista de objetos contendo dados de usuário e fila SQS para cada microsserviço. Usada para provisionar filas e usuários IAM específicos.
   - Exemplo:
      ```hcl
      microservices_sqs_config = [
         {
            key            = "payments"
            sqs_user       = "fcg-payments-sqs-user"
            sqs_queue_name = "fcg-payments-queue.fifo"
         }
      ]
      ```



## Observações

- As variáveis de configuração dos microsserviços controlam a criação dinâmica dos recursos AWS (ECR, EKS, SQS, IAM, S3, CodeBuild, CodePipeline, etc.).
- O bucket S3 é utilizado para armazenar artefatos gerados pelo CodeBuild.
- As permissões necessárias para o CodeBuild acessar o bucket S3 e o cluster EKS são configuradas em `iam.tf`.
- Para adicionar um novo microsserviço, basta incluir um novo objeto nas variáveis de configuração em `configuration.tf`.
- Ajuste as variáveis conforme necessário para seu ambiente.

---

Atualize este README conforme o projeto evoluir.