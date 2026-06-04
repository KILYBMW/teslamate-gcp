# ==============================================================
# PROVIDER
# ==============================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ==============================================================
# VM — Compute Engine
# Zona       : us-west1-b
# Tipo       : e2-micro (2 vCPU, 1 GB RAM)
# Imagen     : Debian 12 Bookworm (x86-64)
# Disco boot : 30 GB pd-standard, lectura/escritura
# Red        : default / default subnet (IPv4)
# Firewall   : Sin reglas adicionales (HTTP/HTTPS desactivados)
# ==============================================================

resource "google_compute_instance" "vm" {
  name         = var.vm_name
  machine_type = "e2-micro"
  zone         = var.zone

  # Disco de arranque ─────────────────────────────────────────
  boot_disk {
    auto_delete = true # El disco se borra al eliminar la instancia

    initialize_params {
      image = "debian-cloud/debian-12" # Siempre toma la última Debian 12
      size  = 30                       # GB
      type  = "pd-standard"            # Disco persistente estándar (HDD)
    }

    mode = "READ_WRITE"
  }

  # Red ────────────────────────────────────────────────────────
  network_interface {
    network    = "default"
    subnetwork = "default"

    # Elimina este bloque si NO quieres IP externa efímera
    access_config {
      # El nivel STANDARD es más económico que el PREMIUM por defecto.
      network_tier = "STANDARD"
    }
  }

  # Disponibilidad y mantenimiento ────────────────────────────
  scheduling {
    automatic_restart   = true      # Reinicio automático activo
    on_host_maintenance = "MIGRATE" # Migrar instancia en mantenimiento del host
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  # Confidential VM ───────────────────────────────────────────
  confidential_instance_config {
    enable_confidential_compute = false
  }

  # Protección contra borrado accidental ──────────────────────
  deletion_protection = false

  # Script de inicio para instalar software automáticamente ───
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e

    # 1. Actualizar e instalar dependencias básicas
    apt-get update
    apt-get install -y ca-certificates curl gnupg

    # 2. Configurar repositorio oficial de Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 3. Instalar Docker y Docker Compose Plugin
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 4. Instalar Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
  EOT

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ==============================================================
# BUCKET — Cloud Storage
# ──────────────────────────────────────────────────────────────
# FREE TIER: 5 GB/mes de almacenamiento Regional en us-west1
#   → Configura una regla de ciclo de vida (ver bloque lifecycle)
#     para no superar ese límite y evitar cargos.
# ──────────────────────────────────────────────────────────────
# Región        : us-west1 (misma que la VM)
# Tipo ubicación: Regional
# Clase         : STANDARD
# Replicación   : Sin replicación entre buckets
# CORS          : No habilitado
# Acceso        : Uniform (IAM únicamente, sin ACLs por objeto)
# Acceso público: Bloqueado — enforced a nivel de bucket
# Versionado    : Desactivado
# Soft delete   : Desactivado (0 días) ← IMPORTANTE para free tier
# Retención     : Sin política de retención
# Encriptación  : Administrada por Google (GMEK)
# ==============================================================

resource "google_storage_bucket" "bucket" {
  name          = var.bucket_name
  location      = upper(var.region)
  storage_class = "STANDARD"

  # Uniform access: solo permisos IAM, sin ACLs individuales por objeto.
  uniform_bucket_level_access = true

  # Bloquea completamente el acceso público al bucket y sus objetos.
  public_access_prevention = "enforced"

  # Soft delete DESACTIVADO.
  # Por defecto GCP activa 7 días de retención "soft delete" que sigue
  # contando contra tu cuota de almacenamiento aunque hayas borrado objetos.
  # Con 0 segundos los objetos borrados desaparecen inmediatamente.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  # Versionado de objetos desactivado.
  versioning {
    enabled = false
  }

  # ──────────────────────────────────────────────────────────
  # REGLA DE CICLO DE VIDA — Personaliza según tus necesidades
  # ──────────────────────────────────────────────────────────
  # GCP ofrece 5 GB/mes gratis en us-west1. Si superas ese límite
  # empezarás a pagar. Añade aquí las reglas que necesites para
  # controlar el volumen de datos. Ejemplos comentados:
  #
  # Borrar objetos con más de N días de antigüedad:
  # lifecycle_rule {
  #   action { type = "Delete" }
  #   condition { age = 30 }   # días
  # }
  #
  # Borrar versiones no actuales (si activas versionado en el futuro):
  # lifecycle_rule {
  #   action { type = "Delete" }
  #   condition { num_newer_versions = 1 }
  # }
  # ──────────────────────────────────────────────────────────

  # Evita que Terraform falle si el bucket tiene objetos al destruir.
  # Ponlo a true SOLO si quieres que terraform destroy borre también los objetos.
  force_destroy = false

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
