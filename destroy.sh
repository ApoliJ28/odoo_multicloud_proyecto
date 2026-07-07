#!/bin/bash
# Detener la ejecución si algún comando falla
set -e 

# Definición de colores ANSI
# ==========================================
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Resetea el formato

# Para capturar cualquier error de ejecución y mostrarlo en ROJO
trap 'echo -e "\n${RED}❌ ERROR: La destrucción falló en la línea $LINENO. Revisa los logs superiores o limpia bloqueos manuales.${NC}"' ERR

echo -e "${RED}🔥 INICIANDO DESTRUCCIÓN TOTAL DE LA INFRAESTRUCTURA (AWS + AZURE)${NC}"
echo -e "${BLUE}===================================================${NC}"

# 0. Limpieza de recursos de Kubernetes
# --------------------------------------------------
echo -e "\n${BLUE}--> 0. Limpiando recursos en Kubernetes (Eliminando LoadBalancers para evitar bloqueos en Terraform)...${NC}"

echo -e "${YELLOW}Limpiando recursos en Azure AKS...${NC}"
kubectl config use-context odoo-azure-aks-cluster || true
kubectl delete -f k8s/ --ignore-not-found=true || true

echo -e "${YELLOW}Limpiando recursos en AWS EKS...${NC}"
if command -v aws &> /dev/null; then
    aws eks update-kubeconfig --region us-east-1 --name odoo-aws-eks-cluster || true
    kubectl delete -f k8s/ --ignore-not-found=true || true
else
    echo -e "${RED}⚠️  AWS CLI no detectado. Si hay LoadBalancers en AWS, podrían bloquear la destrucción.${NC}"
fi


# 1. Destrucción en Azure
# --------------------------------------------------
echo -e "\n${BLUE}--> 1. Destruyendo la infraestructura en Azure (AKS, ACR, Key Vault)...${NC}"
cd terraform/azure
terraform init
# Se incluye el var-file para asegurar que lea las credenciales necesarias para desaprovisionar
terraform destroy -auto-approve -var-file="terraform.tfvars"
cd ../..

# 2. Destrucción en AWS
# --------------------------------------------------
echo -e "\n${BLUE}--> 2. Destruyendo la infraestructura en AWS (EKS, VPC, ECR, Secrets)...${NC}"
cd terraform/aws
terraform init
# El orden interno de dependencias de tu VPC adaptada guiará a Terraform a borrar nodos primero y luego la red
terraform destroy -auto-approve -var-file="terraform.tfvars"
cd ../..

# 3. Limpieza de artefactos locales
# --------------------------------------------------
echo -e "\n${YELLOW}⚠️  Limpiando archivos dinámicos y llaves generadas localmente...${NC}"

rm -f infra.env
rm -f ansible/inventory.ini
rm -f ansible/jenkins_key.pem

echo -e "${GREEN}✅ Archivos locales (infra.env, inventory.ini, jenkins_key.pem) eliminados con éxito.${NC}"

echo -e "${GREEN}💥 ¡Toda la infraestructura cloud ha sido destruida por completo!${NC}"
echo -e "${GREEN}===================================================${NC}"