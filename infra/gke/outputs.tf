output "project_id" {
  value       = var.project_id
  description = "Google Cloud project ID"
}

output "region" {
  value       = var.region
  description = "GKE region"
}

output "cluster_name" {
  value       = google_container_cluster.argo.name
  description = "GKE cluster name"
}

output "network_name" {
  value       = google_compute_network.gke.name
  description = "VPC network name for GKE"
}

output "subnetwork_name" {
  value       = google_compute_subnetwork.gke.name
  description = "Subnetwork name for GKE"
}
