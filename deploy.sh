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
trap 'echo -e "\n${RED}❌ ERROR: El despliegue falló en la línea $LINENO. Revisa los logs superiores.${NC}"' ERR

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}🚀 Iniciando el despliegue multicloud (AWS + AZURE)${NC}"
echo -e "${BLUE}===================================================${NC}"

BUCKET_NAME="odoo-multicloud-terraform-state-aws-bucket-unir-devops"
AWS_REGION="us-east-1"

echo -e "\n${BLUE}--> Verificando bucket S3 para el estado de Terraform...${NC}"
# Se valida si el bucket existe. Al usar 'if', evitamos que 'set -e' aborte el script si da error 404.
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✅ El bucket $BUCKET_NAME ya existe y está accesible.${NC}"
else
    echo -e "${YELLOW}⚠️ El bucket no existe. Creándolo automáticamente en $AWS_REGION...${NC}"
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"

    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    echo -e "${GREEN}✅ Bucket S3 creado y versionado exitosamente.${NC}"
fi
# ==========================================

echo -e "\n${BLUE}--> 1. Levantando la infraestructura en AWS (EKS, ECR, Secrets)...${NC}"
cd terraform/aws
terraform init 
terraform apply -auto-approve 

echo -e "\n${YELLOW}⚠️  Precaución: Limpiando llave SSH anterior (si existe)...${NC}"
rm -f ../../ansible/jenkins_key.pem

echo -e "${BLUE}--> Extrayendo la IP y generando la llave SSH dinámica del orquestador...${NC}"
terraform output -raw jenkins_ssh_private_key > ../../ansible/jenkins_key.pem
chmod 400 ../../ansible/jenkins_key.pem
JENKINS_IP=$(terraform output -raw jenkins_server_ip)

echo -e "${GREEN}✅ IP del Orquestador Central (AWS EC2) obtenida: $JENKINS_IP${NC}"

# Regresamos a la raíz
cd ../../

#prueba despliegue comentario

AZ_RG="odoostorageunir"
AZ_SA="odoostorageunirtfe"
AZ_CONTAINER="odoo-state"
AZ_LOCATION="eastus"

echo -e "\n${BLUE}--> Verificando infraestructura para el estado de Terraform en Azure...${NC}"

# Buscar si la Storage Account ya existe en CUALQUIER grupo de recursos
EXISTING_RG=$(az storage account list --query "[?name=='$AZ_SA'].resourceGroup" -o tsv)

if [ -n "$EXISTING_RG" ]; then
    echo -e "${GREEN}✅ ¡Cuenta manual detectada! La Storage Account '$AZ_SA' ya existe en el Resource Group '$EXISTING_RG'.${NC}"
    AZ_RG="$EXISTING_RG" # Reutilizamos el RG donde ya la tienes creada
else
    echo -e "${YELLOW}⚠️ La Storage Account no existe en la suscripción. Creándola desde cero...${NC}"
    # 1. Verificar/Crear Resource Group
    if az group show --name "$AZ_RG" &>/dev/null; then
        echo -e "${GREEN}✅ El Resource Group $AZ_RG ya existe.${NC}"
    else
        echo -e "${YELLOW}⚠️ Creando Resource Group en $AZ_LOCATION...${NC}"
        az group create --name "$AZ_RG" --location "$AZ_LOCATION" --output none
    fi
    # 2. Crear Storage Account
    az storage account create --name "$AZ_SA" --resource-group "$AZ_RG" --sku Standard_LRS --encryption-services blob --output none
fi

# 3. Verificar/Crear Contenedor (Dentro de la cuenta que encontró o creó)
if az storage container show --name "$AZ_CONTAINER" --account-name "$AZ_SA" &>/dev/null; then
    echo -e "${GREEN}✅ El contenedor $AZ_CONTAINER ya existe y está listo para usarse.${NC}"
else
    echo -e "${YELLOW}⚠️ El contenedor no existe. Creándolo adentro de tu cuenta...${NC}"
    az storage container create --name "$AZ_CONTAINER" --account-name "$AZ_SA" --output none
    echo -e "${GREEN}✅ Infraestructura de estado en Azure lista.${NC}"
fi
# ==========================================

# Despliegue en Azure
echo -e "\n${BLUE}--> 2. Levantando la infraestructura en Azure (AKS, ACR, Key Vault)...${NC}"
cd terraform/azure
terraform init -reconfigure
terraform apply -auto-approve 

# Regresamos a la raíz
cd ../../

# Orquestancion con ansible para instalar Jenkins y Docker en la EC2 de AWS
echo -e "\n${BLUE}--> 3. Generando el inventario de Ansible al vuelo...${NC}"
cd ansible
cat <<EOF > inventory.ini
[jenkins_server]
$JENKINS_IP ansible_user=ubuntu ansible_ssh_private_key_file=./jenkins_key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo -e "\n${BLUE}--> 4. Aprovisionando el Orquestador central con Ansible...${NC}"
# Se ejecuta el playbook usando el inventario recién creado para instalar Jenkins y Docker
ansible-playbook -i inventory.ini playbook.yml

# [CORRECCIÓN]: Regresamos a la raíz después de ejecutar Ansible
cd ..

echo -e "\n${GREEN}===================================================${NC}"
echo -e "${GREEN}✨ Despliegue multicloud completado con éxito!${NC}"
echo -e "${GREEN}🌐 Interfaz de Jenkins disponible en: http://$JENKINS_IP:8080${NC}"
echo -e "${GREEN}===================================================${NC}"

echo -e "\n${BLUE}--> 5. Extrayendo URLs dinámicas de Terraform...${NC}"
# Capturamos las salidas exactas de AWS y Azure
AWS_ECR_URL=$(cd terraform/aws && terraform output -raw ecr_repository_url)
AZURE_ACR_URL=$(cd terraform/azure && terraform output -raw acr_login_server)

# Creamos un archivo de variables para Jenkins en la raíz del repositorio
cat <<EOF > infra.env
AWS_ECR_REPO=$AWS_ECR_URL
AZURE_ACR_REPO=$AZURE_ACR_URL/odoo-app
AWS_REGION=us-east-1
EKS_CLUSTER=odoo-aws-eks-cluster
AKS_RG=odoo-multicloud-rg
AKS_CLUSTER=odoo-azure-aks-cluster
EOF

echo -e "${GREEN}✅ Archivo infra.env generado exitosamente con los mapeos automáticos.${NC}"