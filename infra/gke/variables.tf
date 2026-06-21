variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "GKE region"
  type        = string
  default     = "asia-northeast1"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "argo-workflows-lab"
}

variable "node_count" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "network_name" {
  description = "VPC network name for GKE"
  type        = string
  default     = "argo-gke-vpc"
}

variable "subnetwork_name" {
  description = "Subnetwork name for GKE"
  type        = string
  default     = "argo-gke-subnet"
}

variable "subnetwork_cidr" {
  description = "Primary CIDR for GKE subnetwork"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_secondary_range_name" {
  description = "Secondary range name for pods"
  type        = string
  default     = "gke-pods"
}

variable "pods_secondary_cidr" {
  description = "Secondary CIDR for pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_secondary_range_name" {
  description = "Secondary range name for services"
  type        = string
  default     = "gke-services"
}

variable "services_secondary_cidr" {
  description = "Secondary CIDR for services"
  type        = string
  default     = "10.30.0.0/20"
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

