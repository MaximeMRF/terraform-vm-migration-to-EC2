variable "name" {
  description = "The name"
  type        = string
}

variable "owner" {
  description = "The owner of the resource"
  type        = string
}

variable "project" {
  description = "The project of the resource"
  type        = string
}

variable "aws_region" {
  description = "The AWS region"
  type        = string
  default     = "us-west-2"
}

variable "raw_image_name" {
  description = "The name of the raw image to be imported"
  type        = string
}

variable "deploy_vm" {
  description = "Flag to deploy the VM after import"
  type        = bool
  default     = false
}

variable "vm_custom_ami_id" {
  description = "Custom AMI ID for the VM"
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket to store the raw image"
  type        = string
  default     = "my-raw-image-bucket-demo"
}
