resource "aws_eks_cluster" "main" {
  name     = "odoo-aws-eks-cluster"
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "odoo-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}