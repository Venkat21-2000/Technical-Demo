# Provider Configuration for AWS
provider "aws" {
  region = "ap-northeast-1"
}

# Module Configuration for VPC
module "vpc" {
  source                  = "./vpc"
  region                  = "ap-northeast-1"
  cidr_block              = "10.0.0.0/16"
  vpc_name                = "MainVPC"
  public_subnet_cidr      = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  public_subnet_name      = "PublicSubnet"
  private_subnet_cidr     = "10.0.2.0/24"
  private_subnet_name      = "PrivateSubnet"
  igw_name                = "MainIGW"
  public_route_table_name = "PublicRouteTable"
}

# Module Configuration for EC2 Instances
module "ec2" {
  source                    = "./instance"
  region                    = "ap-northeast-1"
  vpc_id                    = module.vpc.vpc_id
  ami                       = "ami-04b2b41f684d4bd33"
  instance_type             = "t2.micro"
  public_subnet_id          = module.vpc.public_subnet_id
  key_name                  = module.ssh.key_name
  bastion_sg_name           = "BastionSecurityGroup"
  private_instance_sg_name  = "PrivateInstanceSecurityGroup"
  private_instance_role_name= "private-instance-s3"
  private_subnet_id         = module.vpc.private_subnet_id
  private_key_path          = module.ssh.private_key_path

  # IAM Assume Role Policy for EC2 Instances
  assume_role_policy_private = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
 ]
}
EOF

  # IAM Policy ARN for EC2 Instances
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  bastion_instance_name     = "BastionHost"
  private_instance_name     = "PrivateInstance"
  public_subnet_cidr        = module.vpc.public_subnet_cidr # Pass the public_subnet_cidr here
  private_key_pem           = module.ssh.private_key_pem
  bucket_name = module.s3.bucket_name
}

# Module Configuration for S3 Bucket
module "s3" {
  source           = "./s-3"
  region           = "ap-northeast-1"
  bucket_name      = "my-bucket-venky-tech-12"
  s3_bucket_policy  = <<EOF
{
  "Version": "2012-10-17",
  "Id": "Policy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
          "AWS": "${module.ec2.private_instance_role_arn}"
      },
      "Action": "s3:GetObject",
      "Resource": "${module.s3.bucket_arn}/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "${module.ec2.private_ip}/32"
        }
      }
    }
  ]
}
EOF
}

# Module Configuration for SSH Key
module "ssh" {
  source    = "./ssh" 
  key_name  = "ec2-key" 
}

# Terraform Backend Configuration
terraform {
  backend "s3" {
    bucket         = "tfstate-bucket-11"
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    # dynamodb_table = "terraform_locks"
  }
}

# Resource Configuration for Private Key in S3 Bucket
resource "aws_s3_bucket_object" "private_key" {
  bucket = "tfstate-bucket-11"
  key    = "private_key.pem"
  source = module.ssh.private_key_path  
  acl    = "private"
}
