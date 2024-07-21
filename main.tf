provider "aws" {
  region = "ap-northeast-1"  # 서울 리전
}

# VPC 설정
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# 서브넷 설정
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "main-subnet"
  }
}

# 인터넷 게이트웨이 설정
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-internet-gateway"
  }
}

# 라우트 테이블 설정
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-route-table"
  }
}

# 라우트 테이블과 서브넷 연관
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# EC2 인스턴스 설정
resource "aws_instance" "example" {
  ami           = "ami-02d103d746c04361a"  # Amazon Linux 2 ARM64 AMI
  instance_type = "t4g.micro"              # ARM64 아키텍처 지원 인스턴스 타입
  subnet_id     = aws_subnet.main.id

  tags = {
    Name = "example-instance"
  }
}
