variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-west-2"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS cluster for Pod Identity associations"
  default     = "my-cluster"
}