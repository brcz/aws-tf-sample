
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  create = true

  cluster_name                   = local.eks_cluster_name
  cluster_version                = "1.32"
  cluster_endpoint_public_access = true
  control_plane_subnet_ids       = module.vpc.private_subnets
  vpc_id                         = module.vpc.vpc_id

  eks_managed_node_groups = {
    system = {
      name           = "system-eks-mng"
      subnet_ids     = module.vpc.private_subnets
      instance_types = ["t3.large"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      taints = {
        dedicated = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
    worknodes = {
      name           = "worknodes-eks-mng"
      subnet_ids     = module.vpc.private_subnets
      instance_types = ["t3.large"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
    }
  }

  kms_key_enable_default_policy = true

  kms_key_administrators = [
    "arn:aws:iam::008335632463:user/Albina",
    "arn:aws:iam::008335632463:user/Alex",
    "arn:aws:iam::008335632463:user/Konstantin"
  ]

  # Enabling federated IAM roles accessing the EKS cluster
  manage_aws_auth_configmap = true

  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::008335632463:user/Albina"
      username = "albina"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::008335632463:user/Alex"
      username = "alex"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::008335632463:user/Konstantin"
      username = "brcz"
      groups   = ["system:masters"]
    }
  ]

}

resource "aws_eks_addon" "eks" {
  cluster_name = module.eks.cluster_name

  for_each = { for k, v in var.eks_cluster_addons : k => v if var.environment == "dev-us-east-2" }

  addon_name                  = try(each.value.name, each.key)
  addon_version               = lookup(each.value, "addon_version", null)
  resolve_conflicts_on_create = lookup(each.value, "resolve_conflicts_on_create", null)
  resolve_conflicts_on_update = lookup(each.value, "resolve_conflicts_on_update", null)
  service_account_role_arn    = lookup(each.value, "service_account_role_arn", null)

  tags = {
    Name    = "eks-addon-${each.key}"
    Cluster = module.eks.cluster_name
  }

}
