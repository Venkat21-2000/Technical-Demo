provider "aws" {
  region = "ap-northeast-1"
}

module "vpc" {
  source = "./vpc"

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

module "ec2" {
  source = "./instance"

  region                        = "ap-northeast-1"
  vpc_id                        = module.vpc.vpc_id
  ami                           = "ami-04b2b41f684d4bd33"
  instance_type                 = "t2.micro"
  public_subnet_id              = module.vpc.public_subnet_id
  key_name                      = module.ssh.key_name
  bastion_sg_name               = "BastionSecurityGroup"
  private_instance_sg_name      = "PrivateInstanceSecurityGroup"
  private_instance_role_name    = "private-instance-s3-accesss-demo"
  private_subnet_id             = module.vpc.private_subnet_id
  private_key_path = module.ssh.private_key_path
  assume_role_policy            = <<EOF
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
  policy_arn                    = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  bastion_instance_name         = "BastionHost"
  private_instance_name         = "PrivateInstance"
  public_subnet_cidr            =  module.vpc.public_subnet_cidr # Pass the public_subnet_cidr here
  private_key_pem = module.ssh.private_key_pem
}


module "s3" {
  source = "./s-3"

  region            = "ap-northeast-1"
  bucket_name       = "my-bucket-venky-tech"
  s3_bucket_policy  = <<EOF
{
  "Version": "2012-10-17",
  "Id": "Policy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
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

module "ssh" {
  source = "./ssh" 
  key_name = "ec2-key" 

}

terraform {
  backend "s3" {
    bucket         = "tfstate-bucket-11"
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    # dynamodb_table = "terraform_locks"s
  }
}

resource "aws_s3_bucket_object" "private_key" {
  bucket = "tfstate-bucket-11"
  key    = "private_key.pem"
  source = module.ssh.private_key_path  
  acl    = "private"
}

