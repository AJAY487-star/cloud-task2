provider "aws" {
  region  = "ap-south-1"
  profile = "pintu"
}


resource "aws_security_group" "cloudtask2-sgroup" {
  name        = "cloudtask2-sgrop"
  description = "HTTP, SSH, NFS"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudtask2_sgroup"
  }
}


resource "aws_efs_file_system" "task2efs" {
  creation_token = "task2efs"

  tags = {
    Name = "task2efs"
  }

  depends_on = [
    aws_security_group.cloudtask2-sgroup,
  ]
}


resource "aws_efs_mount_target" "efs-mount" {
  file_system_id = aws_efs_file_system.task2efs.id
  subnet_id      = "subnet-23a7cc6f"
  security_groups = [aws_security_group.cloudtask2-sgroup.id]

    depends_on = [
    aws_efs_file_system.task2efs,
  ]
}


resource "tls_private_key" "cloudt2key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "cloudt2key" {
  key_name = "mytask2-key"
  public_key = tls_private_key.cloudt2key.public_key_openssh
}


resource "aws_instance" "Task2" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "mytask2-key"
  subnet_id      = "subnet-23a7cc6f"
  security_groups = [aws_security_group.cloudtask2-sgroup.id]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.cloudt2key.private_key_pem
    host     = aws_instance.Task2.public_ip
 }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo yum install nfs-utils -y",
      "sudo yum install amazon-efs-utils -y",
      "sudo yum install git -y",
      "sudo mount -t efs ${aws_efs_file_system.task2efs.id}:/ /var/www/html",
      "sudo echo ${aws_efs_file_system.task2efs.id}:/ /var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
      "sudo rm -f /var/www/html/*",
      "sudo git clone https://github.com/AJAY487-star/cloud-task2.git /var/www/html/",
    ]
  }
      
  tags = {
    Name = "Task2"
  }

    depends_on = [
    aws_efs_mount_target.efs-mount,
  ]
}


resource "aws_s3_bucket" "buckettask2" {
  bucket = "baket123432156task2"
  acl    = "public-read"

  tags = {
    Name        = "baket123432156task2"
  }
}


resource "aws_s3_bucket_object" "cloudtask2-img" {
  bucket = aws_s3_bucket.buckettask2.bucket
  key = "lordShiva"
  content_type = "image/jpg"
  source = "C:/Pintu/task2/mahadev.jpg"
  acl = "public-read"

    depends_on = [
    aws_s3_bucket.buckettask2,
  ]
}


resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "task2_cf"

    depends_on = [
    aws_s3_bucket_object.cloudtask2-img,
  ]
}

locals {
 s3_origin_id = "aws_s3_bucket.baket123432156task2.id"
}


resource "aws_cloudfront_distribution" "task2-clouddist" {
  enabled = true
  is_ipv6_enabled = true

  origin {
    domain_name = aws_s3_bucket.buckettask2.bucket_domain_name
    origin_id = local.s3_origin_id
  }

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    aws_cloudfront_origin_access_identity.oai,
  ]

}


resource "null_resource" "AJnull" {
 connection {
  type     = "ssh"
  user     = "ec2-user"
  private_key = tls_private_key.cloudt2key.private_key_pem
  host     = aws_instance.Task2.public_ip
 }

 provisioner "remote-exec" {
  inline = [
   "sudo su << EOF",
   "echo \"<img src='http://${aws_cloudfront_distribution.task2-clouddist.domain_name}/${aws_s3_bucket_object.cloudtask2-img.key}' height='400' width = '400'>\" >> /var/www/html/index.html",
   "EOF",
   "sudo systemctl restart httpd",
  ]
 }
  depends_on = [ 
   aws_cloudfront_distribution.task2-clouddist,
   aws_instance.Task2,
  ]
}


output "Instance_IP" {
  value = aws_instance.Task2.public_ip
}