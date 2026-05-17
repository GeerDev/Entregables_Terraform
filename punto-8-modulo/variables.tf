variable "region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "eu-west-3"
}

variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Nombre del proyecto, usado para etiquetar los recursos"
  type        = string
  default     = "entregable-terraform"
}

variable "subnet_cidr" {
  description = "CIDR block para la subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "my_ip" {
  description = "Lista de IPs públicas en formato CIDR (ej: [\"203.0.113.5/32\"]) para acceso SSH por el puerto 22"
  type        = list(string)
}

variable "public_key_path" {
  description = "Ruta a tu clave pública SSH (ej: ~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 (free tier: t2.micro)"
  type        = string
  default     = "t2.micro"
}
