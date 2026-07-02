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
  subnet_ids      = var.private_subnet_ids # Por fines de usar aws academy, colocamos los nodos en subredes públicas. En un entorno real, deberían estar en subredes privadas. y teener NET Gateway y NAT Gateway para que puedan salir a internet.
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}