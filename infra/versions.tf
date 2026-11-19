terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Fase 1: estado local (arquivo terraform.tfstate, fora do Git).
  # Próxima fase: backend remoto em S3 com lock, para o pipeline aplicar a infra.
}

provider "aws" {
  region = var.regiao

  # Toda peça criada sai etiquetada: facilita achar no console e somar o custo
  default_tags {
    tags = {
      Projeto       = var.projeto
      Disciplina    = "DevOps na Pratica - PUCRS"
      GerenciadoPor = "terraform"
    }
  }
}
