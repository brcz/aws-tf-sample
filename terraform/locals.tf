locals {
  base_name                             = "${var.service}-${var.environment}"

  storage_data_s3_bucket_name         = "s3-storage-data-${local.base_name}"

  dns_local_domain                      = "${var.environment}-sample.local"
 
  eks_cluster_name                      = "eks-${local.base_name}"
  bastion_name                          = "bastion-${local.base_name}"

  # SQS
  sample_app_sqs_name                           = "sqs-sample-app-${local.base_name}"

}
