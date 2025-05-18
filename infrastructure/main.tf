provider "aws" {
  region = "us-west-2"  # Oregon region
}

# Create a Lightsail instance
resource "aws_lightsail_instance" "q_server" {
  name              = "q-server"
  availability_zone = "us-west-2a"
  blueprint_id      = "amazon_linux_2"
  bundle_id         = "nano_3_0"  # Smallest instance, can be upgraded later

  user_data = <<-EOF
    #!/bin/bash
    # Install necessary packages
    yum update -y
    yum install -y nginx docker
    systemctl enable docker
    systemctl start docker
    systemctl enable nginx
    systemctl start nginx

    # Configure nginx as reverse proxy
    cat > /etc/nginx/conf.d/default.conf <<'EOT'
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

    # Restart nginx to apply changes
    systemctl restart nginx
  EOF

  tags = {
    Name = "q-command-center"
  }
}

# Open ports for the Lightsail instance
resource "aws_lightsail_instance_public_ports" "q_server_ports" {
  instance_name = aws_lightsail_instance.q_server.name

  port_info {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
  }

  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }
}

# Create a static IP for the Lightsail instance
resource "aws_lightsail_static_ip" "q_server_ip" {
  name = "q-server-static-ip"
}

# Attach the static IP to the Lightsail instance
resource "aws_lightsail_static_ip_attachment" "q_server_ip_attachment" {
  static_ip_name = aws_lightsail_static_ip.q_server_ip.name
  instance_name  = aws_lightsail_instance.q_server.name
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
  records = [aws_lightsail_static_ip.q_server_ip.ip_address]
}

# Output the instance IP and DNS
output "instance_ip" {
  value = aws_lightsail_static_ip.q_server_ip.ip_address
}

output "instance_dns" {
  value = aws_route53_record.q_subdomain.fqdn
}
