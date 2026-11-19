variable "regiao" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}

variable "projeto" {
  description = "Prefixo dos nomes dos recursos"
  type        = string
  default     = "biblioteca"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.projeto))
    error_message = "Use letras minúsculas, números e hífen."
  }
}

variable "cidr_vpc" {
  description = "Faixa de IPs da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "papel_lab" {
  description = "Papel do IAM usado pelo ECS (no Learner Lab é o LabRole)"
  type        = string
  default     = "LabRole"
}

variable "tag_imagem" {
  description = "Tag da imagem no ECR"
  type        = string
  default     = "latest"
}

variable "porta_container" {
  description = "Porta da API no container"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "CPU da tarefa (256 = 0,25 vCPU)"
  type        = number
  default     = 256
}

variable "memoria" {
  description = "Memória da tarefa em MB"
  type        = number
  default     = 512
}

variable "quantidade_tarefas" {
  description = "Quantidade de tarefas rodando"
  type        = number
  default     = 1

  validation {
    condition     = var.quantidade_tarefas >= 0 && var.quantidade_tarefas <= 4
    error_message = "Use de 0 a 4 tarefas."
  }
}

variable "dias_retencao_logs" {
  description = "Dias de retenção dos logs"
  type        = number
  default     = 7
}
