
resource "tls_private_key" "bastion" {
  count = var.bastion_generate_private_key && var.bastion_enabled ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create Key Pair
resource "aws_key_pair" "bastion" {
  count = var.bastion_generate_private_key && var.bastion_enabled ? 1 : 0

  key_name   = "kp-${local.bastion_name}"
  public_key = trimspace(tls_private_key.bastion[0].public_key_openssh)
}

resource "aws_instance" "bastion" {
  count                       = var.bastion_enabled ? 1 : 0
  ami                         = data.aws_ami.bastion.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].name
  instance_type               = var.bastion_instance_type
  key_name                    = aws_key_pair.bastion[0].key_name

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = "20"
    volume_type           = "gp2"
  }

  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = compact(concat([aws_security_group.bastion[0].id], var.bastion_security_groups))

  tags = {
    Name = "ec2-${local.bastion_name}"
  }
  user_data_replace_on_change = true
  user_data                   = <<-EOT
  #!/bin/bash
  sudo apt upgrade && sudo apt upgrade -y
  sudo apt-get install awscli -y
  snap install kubectl --classic
  EOT
}

resource "aws_eip" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  instance = aws_instance.bastion[0].id
  domain   = "vpc"
}

# Security group
resource "aws_security_group" "bastion" {
  count = var.bastion_enabled ? 1 : 0


  #NOTE: Security Group name cannot begin with "sg-"
  name        = "secgroup-${local.bastion_name}-service"
  description = "Bastion host sec group"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  lifecycle {
    create_before_destroy = true
  }
}

#region IAM Role & Instance Profile

resource "aws_iam_role" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name        = "iam-role-ec2-${local.bastion_name}"
  description = "ec2-${local.bastion_name} EC2 Instance Role"

  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy.json
  force_detach_policies = true

}
resource "aws_iam_policy" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name        = "iam-policy-ec2-${local.bastion_name}-ssm"
  description = "The policy for Amazon EC2 Role to enable AWS Systems Manager Session Manager functionality on Bastion EC2 instance"

  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ec2messages:AcknowledgeMessage",
            "ec2messages:DeleteMessage",
            "ec2messages:FailMessage",
            "ec2messages:GetEndpoint",
            "ec2messages:GetMessages",
            "ec2messages:SendReply",
            "ssm:DescribeAssociation",
            "ssm:GetDeployablePatchSnapshotForInstance",
            "ssm:GetDocument",
            "ssm:DescribeDocument",
            "ssm:GetManifest",
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:ListAssociations",
            "ssm:ListInstanceAssociations",
            "ssm:PutInventory",
            "ssm:PutComplianceItems",
            "ssm:PutConfigurePackageResult",
            "ssm:UpdateAssociationStatus",
            "ssm:UpdateInstanceAssociationStatus",
            "ssm:UpdateInstanceInformation",
            "ssm:UpdateInstanceInformation",
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"
          ]
          Resource = "*"
        },
        {
          Sid    = "AllowAccessToSSMSessionsEncryptionKMS"
          Effect = "Allow"
          Action = [
            "kms:CreateGrant",
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey*",
            "kms:ReEncrypt*"
          ]
          Resource = [
            aws_kms_key.bastion[0].arn
          ]
        },
        {
          Sid    = "AllowSSMSToDescribeLogGroups"
          Effect = "Allow"
          Action = [
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ]
          Resource = [
            "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*"
          ]
        },
        {
          Sid    = "AllowSSMStreamToCloudWatchLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = [
            aws_cloudwatch_log_group.bastion[0].arn
          ]
        }
      ]
    }
  )
}
resource "aws_iam_role_policy_attachment" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  policy_arn = aws_iam_policy.bastion[0].arn
  role       = aws_iam_role.bastion[0].name
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  role = aws_iam_role.bastion[0].name

  name = "iam-instance-profile-ec2-${local.bastion_name}"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_kms_key" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  deletion_window_in_days  = 10
  enable_key_rotation      = true
  description              = "Systems Manager sessions encryption"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  multi_region             = true
  policy                   = <<EOF
    {
      "Version" : "2012-10-17",
      "Id" : "key-default-1",
      "Statement" : [ {
          "Sid" : "Enable IAM User Permissions",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          },
          "Action" : "kms:*",
          "Resource" : "*"
        },
        {
          "Effect": "Allow",
          "Principal": { "Service": "logs.${var.aws_region}.amazonaws.com" },
          "Action": [
            "kms:Encrypt*",
            "kms:Decrypt*",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:Describe*"
          ],
          "Resource": "*"
        }
      ]
    }
EOF

}

resource "aws_kms_alias" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name          = "alias/gss/${local.bastion_name}"
  target_key_id = aws_kms_key.bastion[0].key_id
}

resource "aws_cloudwatch_log_group" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name              = "ec2/gss/${local.bastion_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.bastion[0].arn
}

#endregion

resource "aws_ssm_document" "bastion" {
  count           = var.bastion_enabled ? 1 : 0
  name            = "SSM-GSSBastionRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document to hold regional preferences for Session Manager"
    sessionType   = "Standard_Stream"
    inputs = {
      kmsKeyId                    = aws_kms_key.bastion[0].key_id
      s3BucketName                = ""
      s3KeyPrefix                 = ""
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.bastion[0].name
      cloudWatchEncryptionEnabled = false
      cloudWatchStreamingEnabled  = true
      idleSessionTimeout          = "60"
      maxSessionDuration          = tostring(null)
      runAsEnabled                = false
      runAsDefaultUser            = ""
      shellProfile = {
        linux   = ""
        windows = ""
      }
    }
  })
}
