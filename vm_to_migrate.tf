provider "aws" {
  region = var.aws_region
}

locals {
  region   = var.aws_region
  vpc_cidr = "10.0.0.0/16"
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]

  tags = {
    Name    = var.name
    Project = var.project
    Owner   = var.owner
  }
}

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_s3_bucket" "raw_image_bucket" {
  bucket = var.s3_bucket_name
  force_destroy = true
  tags = local.tags
}

resource "aws_s3_object" "raw_image" {
  bucket = aws_s3_bucket.raw_image_bucket.id
  key    = "${var.raw_image_name}"
  source = "./${var.raw_image_name}"
  etag   = filemd5("./${var.raw_image_name}")
  tags   = local.tags
}

resource "aws_iam_role" "vmimport" {
  name = "vmimport"
  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "vmie.amazonaws.com" },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": { "sts:ExternalId": "vmimport" }
    }
  }]
})
}

resource "aws_iam_role_policy" "vmimport_policy" {
  name = "vmimport-policy"
  role = aws_iam_role.vmimport.id
  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement":[
    {
      "Effect":"Allow",
      "Action":[
        "s3:GetBucketLocation","s3:ListBucket","s3:GetObject","s3:PutObject"
      ],
      "Resource":[
        "arn:aws:s3:::my-raw-image-bucket-demo",
        "arn:aws:s3:::my-raw-image-bucket-demo/*"
      ]
    },
    {
      "Effect":"Allow",
      "Action":[
        "ec2:ImportImage","ec2:DescribeImportImageTasks",
        "ec2:ModifySnapshotAttribute","ec2:CopySnapshot",
        "ec2:RegisterImage","ec2:Describe*"
      ],
      "Resource":"*"
    },
    {
      "Effect":"Allow",
      "Action":[
        "kms:CreateGrant","kms:Decrypt","kms:DescribeKey",
        "kms:Encrypt","kms:GenerateDataKey*","kms:ReEncrypt*"
      ],
      "Resource":"*"
    }
  ]
}
)
}

resource "null_resource" "import_raw_image" {
  provisioner "local-exec" {
    command = <<EOT
      aws ec2 import-image \
        --description "Raw disk imported" \
        --role-name ${aws_iam_role.vmimport.name} \
        --disk-containers '[
          {
            "Description": "Imported raw image",
            "Format": "raw",
            "Url": "s3://${aws_s3_object.raw_image.bucket}/${var.raw_image_name}"
          }
        ]'
    EOT
  }

  depends_on = [aws_iam_role_policy.vmimport_policy, aws_s3_object.raw_image]
}

resource "aws_key_pair" "vm_key" {
  key_name   = "vm-key"
  // replace with your public key file path
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_security_group" "vm_sg" {
  name        = "vm-security-group"
  description = "Security group for the VM"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_instance" "raw_instance" {
  count = var.deploy_vm ? 1 : 0
  instance_type = "t3.small"
  ami = var.vm_custom_ami_id
  subnet_id     = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name = aws_key_pair.vm_key.key_name

  tags = local.tags
}
