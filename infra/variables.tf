variable "regiao" {
  description = "Região da AWS. O AWS Academy Learner Lab trabalha em us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "projeto" {
  description = "Prefixo dos nomes de todos os recursos."
  type        = string
  default     = "biblioteca"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.projeto))
    error_message = "Use de 3 a 21 caracteres: letras minúsculas, números e hífen, começando por letra."
  }
}

variable "cidr_vpc" {
  description = "Faixa de endereços da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "papel_lab" {
  description = "Papel do IAM que as tarefas do ECS assumem. O Learner Lab não deixa criar papéis, só usar o LabRole que já existe."
  type        = string
  default     = "LabRole"
}

variable "tag_imagem" {
  description = "Tag da imagem no ECR que o serviço vai rodar (o pipeline publica com o SHA do commit)."
  type        = string
  default     = "latest"
}

variable "porta_container" {
  description = "Porta em que a API escuta dentro do container."
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "CPU da tarefa Fargate em unidades (256 = 0,25 vCPU, o menor tamanho)."
  type        = number
  default     = 256
}

variable "memoria" {
  description = "Memória da tarefa Fargate em MiB (512 é o mínimo para 256 de CPU)."
  type        = number
  default     = 512
}

variable "quantidade_tarefas" {
  description = "Quantas cópias da API ficam rodando. 0 desliga a API sem destruir o resto."
  type        = number
  default     = 1

  validation {
    condition     = var.quantidade_tarefas >= 0 && var.quantidade_tarefas <= 4
    error_message = "Use de 0 a 4 tarefas, para não estourar o crédito do laboratório."
  }
}

variable "dias_retencao_logs" {
  description = "Por quantos dias o CloudWatch guarda os logs da API."
  type        = number
  default     = 7
}
