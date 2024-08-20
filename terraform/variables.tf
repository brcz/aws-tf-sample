variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "A name that identifies the environment, will used as prefix and for tagging."
  default     = "sample-app"
  type        = string
}

variable "service" {
  description = "It is the friendly name of a standalone system used by technical and non-technical people."
  type        = string
  default     = "app"
}

variable "eks_cluster_addons" {
  description = "List of EKS cluster addons"
  type        = any
  default = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }

  }
}

#region Bastion host variables

variable "bastion_enabled" {
  type        = bool
  default     = false
  description = "Whether or not to enable bastion host"
}

variable "bastion_instance_type" {
  type        = string
  default     = "t2.micro"
  description = "Bastion instance type"
}

variable "bastion_generate_private_key" {
  type        = bool
  default     = true
  description = "Whether or not to generate an SSH key"
}

variable "bastion_security_groups" {
  type        = list(string)
  default     = []
  description = "List of Security Group IDs allowed to connect to the bastion host"
}

#endregion