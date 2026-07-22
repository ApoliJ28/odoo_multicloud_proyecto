variable "vpc_cidr" {
  type = string
}

variable "nombre_proyecto" {
  type = string
}

variable "cluster_name" {
  description = "Nombre del cluster EKS para el tagging de subredes"
  type        = string
}
