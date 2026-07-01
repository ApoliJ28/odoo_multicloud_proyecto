module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}

module "iam" {
  source = "./modules/iam"
}

module "eks" {
  source             = "./modules/eks"
  cluster_role_arn   = module.iam.eks_cluster_role_arn
  node_role_arn      = module.iam.eks_node_role_arn
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets
}

module "services" {
  source = "./modules/services"
  db_user             = var.db_user
  db_password         = var.db_password
  admin_password      = var.admin_password
}
module "jenkins" {
  source           = "./modules/jenkins"
  vpc_id           = module.vpc.vpc_id
  # Colocamos la instancia en la primera subred pública para que tenga salida a internet
  public_subnet_id = module.vpc.public_subnets[0] 
}