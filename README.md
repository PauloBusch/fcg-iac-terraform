# FCG IaC Terraform

Este repositório contém a infraestrutura como código (IaC) para provisionamento de recursos AWS utilizando Terraform, incluindo OpenSearch, IAM, ECR e CodeBuild.

## Estrutura dos Arquivos

- `main.tf`: Configuração do provider AWS.
- `variables.tf`: Definição de variáveis utilizadas no projeto.
- `iam.tf`: Recursos relacionados a usuários, grupos e permissões IAM.
- `opensearch.tf`: Provisionamento do domínio OpenSearch e permissões de acesso.
- `ecr.tf`: (Adicionar descrição se aplicável)
- `codebuild.tf`: (Adicionar descrição se aplicável)
- `terraform.tfstate`, `terraform.tfstate.backup`: Arquivos de estado do Terraform.

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

## Variáveis principais

- `aws_region`: Região AWS (padrão: us-east-2)
- `users`: Lista de usuários IAM para OpenSearch
- `opensearch_domain`: Nome do domínio OpenSearch
- `opensearch_user_group_name`: Nome do grupo de usuários OpenSearch
- `github_user` e `github_repo`: Informações do repositório GitHub

## Observações

- Certifique-se de que os usuários definidos em `users` existam ou serão criados corretamente.
- Ajuste as variáveis conforme necessário para seu ambiente.

---

Atualize este README conforme o projeto evoluir.
