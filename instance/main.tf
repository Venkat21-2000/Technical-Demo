provider "aws" {
  region = var.region
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic to AWS services and allow incoming traffic from private instance
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.private_instance_sg.id]
  }

  tags = {
    Name = var.bastion_sg_name
  }
}

resource "aws_security_group" "private_instance_sg" {
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr]
  }

  # Allow outbound traffic to AWS services, but deny access to the specific S3 bucket
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    prefix_list_ids = ["pl-61a54008"]  # Replace with the correct prefix list ID for your S3 region
  }

  tags = {
    Name = var.private_instance_sg_name
  }
}

resource "aws_iam_role" "bastion_role" {
  name = "bastion-role1111"
  path = "/"

  assume_role_policy = var.assume_role_policy_private
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-profile"
  role = aws_iam_role.bastion_role.name

}

resource "aws_iam_role_policy" "s3_access_policy" {
  name   = "s3-access-policy"
  role   = aws_iam_role.bastion_role.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${var.bucket_name}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_instance" "bastion" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_name

  provisioner "remote-exec" {
    inline = [
      "echo '${var.private_key_pem}' > /home/ec2-user/private_key.pem",
      "chmod 400 /home/ec2-user/private_key.pem"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.private_key_pem
      host        = self.public_ip
    }
  }

  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name

  tags = {
    Name = var.bastion_instance_name
  }
}

resource "aws_iam_role" "private_instance_role" {
  name = var.private_instance_role_name
  path = "/"

  assume_role_policy = var.assume_role_policy_private
}

resource "aws_iam_role_policy_attachment" "private_instance_policy" {
  policy_arn = var.policy_arn
  role       = aws_iam_role.private_instance_role.name
}

resource "aws_iam_instance_profile" "private_instance_profile" {
  name = "${var.private_instance_role_name}_profile"
  role = aws_iam_role.private_instance_role.name
}

resource "aws_instance" "private_instance" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.private_instance_sg.id]
  key_name               = var.key_name

  depends_on = [aws_iam_role.private_instance_role]

  provisioner "local-exec" {
    command = "sleep 120"
  }

  iam_instance_profile = aws_iam_instance_profile.private_instance_profile.name

  tags = {
    Name = var.private_instance_name
  }
}


