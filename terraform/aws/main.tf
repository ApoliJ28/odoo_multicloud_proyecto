module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  nombre_proyecto = var.nombre_proyecto
}

# En AWS Academy da error al crear los roles de IAM, por lo que se comenta este módulo y se coloca el rol de aws academy (labrol).

# module "iam" {
#   source = "./modules/iam"
# }

module "eks" {
  source             = "./modules/eks"
  cluster_role_arn   = "arn:aws:iam::811180737155:role/LabRole" #Rol de IAM para el cluster EKS, si no colocar la variable que viene de iam.
  node_role_arn      = "arn:aws:iam::811180737155:role/LabRole" #Rol de IAM para los nodos del cluster EKS si no colocar la variable que viene de iam.
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