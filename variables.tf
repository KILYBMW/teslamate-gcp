# ==============================================================
# VARIABLES — Solo debes modificar terraform.tfvars
# ==============================================================

variable "project_id" {
  description = "ID del proyecto de GCP donde se desplegarán los recursos."
  type        = string
}

variable "vm_name" {
  description = "Nombre que tendrá la VM en Compute Engine."
  type        = string
}

variable "bucket_name" {
  description = "Nombre del bucket de Cloud Storage. Debe ser globalmente único en todo GCP."
  type        = string
}

variable "region" {
  description = "Región de GCP para los recursos."
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "Zona de GCP para la VM."
  type        = string
  default     = "us-west1-b"
}

variable "environment" {
  description = "Entorno de despliegue (ej: dev, staging, prod)."
  type        = string
  default     = "dev"
}
