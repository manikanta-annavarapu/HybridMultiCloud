provider  "aws"{
    region = "ap-south-1"
    profile = "mani-root"
}


resource "aws_security_group" "tf-aws-sg" {
  name        = "tf-aws-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-97c1dcff"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
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
    Name = "sg1-for-tf"
  }
}


resource "aws_ebs_volume" "tf-aws-volume" {
  availability_zone = "${aws_instance.tf-ec2-webserver.availability_zone}"
  size = 1
  tags = {
    Name = "MyVolume"
  }
}


resource "aws_instance" "tf-ec2-webserver" {
    ami = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "mkey2"
    security_groups = [ "tf-aws-sg"  ]
    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("F:/HybridMultiCloud/mkey2.pem")
        host = aws_instance.tf-ec2-webserver.public_ip
    }
    provisioner "remote-exec" {
        inline = [
            "sudo yum install httpd  php git -y",
            "sudo systemctl restart httpd",
            "sudo systemctl enable httpd",
        ]
    }

    tags = {
        Name = "os-for-webserver"
    }
}


resource "null_resource" "tf-remote-exec"  {

depends_on = [
    aws_volume_attachment.tf-attach-volume,
]

connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("F:/HybridMultiCloud/mkey2.pem")
    host = aws_instance.tf-ec2-webserver.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/manikanta-annavarapu/HybridMultiCloud.git /var/www/html/"
    ]
  }
}


resource "aws_volume_attachment" "tf-attach-volume" {
   device_name = "/dev/sdh"
   volume_id   =  "${aws_ebs_volume.tf-aws-volume.id}"
   instance_id = "${aws_instance.tf-ec2-webserver.id}"
   depends_on = [
       aws_ebs_volume.tf-aws-volume,
       aws_instance.tf-ec2-webserver
   ]
 }

resource "aws_s3_bucket" "terraform-s3-bucket" {
  bucket = "manikannavm"
  acl    = "public-read"
}


resource "aws_s3_bucket_object" "tf-image" {
  bucket = "manikannavm"
  key    = "goofy.jpg"
  source = "goofy.jpg"
  acl = "public-read"
  content_type = "image/jpg"
  depends_on = [
      aws_s3_bucket.terraform-s3-bucket
  ]
}

resource "aws_cloudfront_distribution" "tf-cloudfront" {
    origin {
        domain_name = "manikannavm.s3.amazonaws.com"
        origin_id   = "S3-manikannavm" 

        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true

    default_cache_behavior {
        allowed_methods = ["GET","HEAD", "OPTIONS"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-manikannavm"

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
        aws_s3_bucket_object.tf-image
    ]
}