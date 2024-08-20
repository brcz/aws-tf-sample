

resource "aws_s3_bucket" "storage_data" {
  bucket = local.storage_data_s3_bucket_name
}
