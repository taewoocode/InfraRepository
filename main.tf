provider "aws" {
  region = "ap-northeast-1"  # 서울 리전
}

# VPC 설정
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# 서브넷 설정
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"  # 다른 가용 영역으로 변경

  tags = {
    Name = "private-subnet"
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
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# EKS 클러스터 생성
resource "aws_eks_cluster" "example" {
  name     = "example-cluster"
  role_arn  = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]
  }

  tags = {
    Name = "example-cluster"
  }
}

# EKS 노드 그룹 생성
resource "aws_eks_node_group" "taewoo_group" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "TaewooGroup"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids       = [aws_subnet.public.id, aws_subnet.private.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t4g.medium"]

  tags = {
    Name = "TaewooGroup"
  }
}
