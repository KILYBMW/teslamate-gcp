# ==============================================================
# OUTPUTS — Información útil tras el despliegue
# ==============================================================

output "vm_name" {
  description = "Nombre de la VM desplegada."
  value       = google_compute_instance.vm.name
}

output "vm_internal_ip" {
  description = "Dirección IP interna de la VM."
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "vm_external_ip" {
  description = "Dirección IP externa efímera de la VM (si se configuró)."
  value       = try(google_compute_instance.vm.network_interface[0].access_config[0].nat_ip, "Sin IP externa")
}

output "vm_zone" {
  description = "Zona donde está desplegada la VM."
  value       = google_compute_instance.vm.zone
}

output "bucket_name" {
  description = "Nombre del bucket de Cloud Storage."
  value       = google_storage_bucket.bucket.name
}

output "bucket_url" {
  description = "URL del bucket."
  value       = google_storage_bucket.bucket.url
}

output "bucket_location" {
  description = "Región del bucket."
  value       = google_storage_bucket.bucket.location
}
