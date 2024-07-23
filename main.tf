provider "aws" {
  region = "ap-northeast-1"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.example.endpoint
  token                  = data.aws_eks_cluster_auth.example.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.example.certificate_authority[0].data)
}

data "aws_eks_cluster_auth" "example" {
  name = aws_eks_cluster.example.name
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

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
  availability_zone       = "ap-northeast-1c"

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-internet-gateway"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "main-nat-gateway"
  }
}

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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eks_cluster" "example" {
  name     = "example-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_policy
  ]
}

resource "aws_eks_node_group" "public_nodes" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "public-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [aws_subnet.public.id]
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t4g.nano"]

  tags = {
    Name = "public-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.s3_access_policy,
    aws_iam_role_policy_attachment.cloudwatch_logs_policy
  ]
}

resource "aws_eks_node_group" "private_nodes" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "private-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [aws_subnet.private.id]
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t4g.nano"]

  tags = {
    Name = "private-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.s3_access_policy,
    aws_iam_role_policy_attachment.cloudwatch_logs_policy
  ]
}

resource "aws_instance" "public_instance" {
  ami           = "ami-0b44ce1dad7c202b7"
  instance_type = "t4g.nano"
  subnet_id     = aws_subnet.public.id
  associate_public_ip_address = true

  tags = {
    Name = "PublicInstance"
  }
}

resource "aws_instance" "private_instance" {
  ami           = "ami-0b44ce1dad7c202b7"
  instance_type = "t4g.nano"
  subnet_id     = aws_subnet.private.id

  tags = {
    Name = "PrivateInstance"
  }
}

resource "aws_lb" "nlb" {
  name               = "example-nlb"
  internal           = false
  load_balancer_type = "network"
  subnet_mapping {
    subnet_id = aws_subnet.public.id
  }
  enable_deletion_protection = false

  tags = {
    Name = "example-nlb"
  }
}

resource "aws_lb_target_group" "example" {
  name     = "example-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
  }

  tags = {
    Name = "example-target-group"
  }
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb_target_group_attachment" "example" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.public_instance.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "example_private" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.private_instance.id
  port             = 80
}

resource "kubernetes_cluster_role" "example" {
  metadata {
    name = "example-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "example-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.example.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "example-service-account"
    namespace = "default"
  }
}
