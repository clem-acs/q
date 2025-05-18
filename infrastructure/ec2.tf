provider "aws" {
  region = "us-west-2"  # Oregon region
}

# Create a VPC
resource "aws_vpc" "q_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "q-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "q_public_subnet" {
  vpc_id                  = aws_vpc.q_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "q-public-subnet"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "q_igw" {
  vpc_id = aws_vpc.q_vpc.id

  tags = {
    Name = "q-igw"
  }
}

# Create a route table
resource "aws_route_table" "q_public_rt" {
  vpc_id = aws_vpc.q_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.q_igw.id
  }

  tags = {
    Name = "q-public-rt"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "q_public_rta" {
  subnet_id      = aws_subnet.q_public_subnet.id
  route_table_id = aws_route_table.q_public_rt.id
}

# Create a security group
resource "aws_security_group" "q_sg" {
  name        = "q-sg"
  description = "Security group for Q Command Center"
  vpc_id      = aws_vpc.q_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "q-sg"
  }
}

# Create a key pair
resource "aws_key_pair" "q_key_pair" {
  key_name   = "q-key-pair"
  public_key = file("${path.module}/q_key.pub")
}

# Create an EC2 instance
resource "aws_instance" "q_server" {
  ami                    = "ami-0b9f27b05e1de14e9"  # Amazon Linux 2023 AMI in us-west-2
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.q_key_pair.key_name
  subnet_id              = aws_subnet.q_public_subnet.id
  vpc_security_group_ids = [aws_security_group.q_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    dnf update -y
    
    # Install Docker
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    
    # Install Nginx
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    
    # Configure Nginx as reverse proxy
    cat > /etc/nginx/conf.d/default.conf << 'EOT'
    server {
        listen 80;
        server_name q.condu.it;
    
        location / {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
    EOT
    
    # Restart Nginx to apply changes
    systemctl restart nginx
    
    # Create app directory
    mkdir -p /home/ec2-user/app
    chown -R ec2-user:ec2-user /home/ec2-user/app
  EOF

  tags = {
    Name = "q-server"
  }
}

# Create an Elastic IP
resource "aws_eip" "q_eip" {
  domain = "vpc"
  tags = {
    Name = "q-eip"
  }
}

# Associate the Elastic IP with the EC2 instance
resource "aws_eip_association" "q_eip_assoc" {
  instance_id   = aws_instance.q_server.id
  allocation_id = aws_eip.q_eip.id
}

# Get the hosted zone ID for condu.it
data "aws_route53_zone" "condu_it" {
  name = "condu.it."
}

# Create DNS record for q.condu.it
resource "aws_route53_record" "q_subdomain" {
  zone_id = data.aws_route53_zone.condu_it.zone_id
  name    = "q.condu.it"
  type    = "A"
  ttl     = 300
  records = [aws_eip.q_eip.public_ip]
}

# Output the instance IP and DNS
output "instance_ip" {
  value = aws_eip.q_eip.public_ip
}

output "instance_dns" {
  value = aws_route53_record.q_subdomain.fqdn
}
