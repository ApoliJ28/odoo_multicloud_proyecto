#!/bin/bash
# Detener la ejecución si algún comando falla
set -e 

echo "Iniciando el despliegue multicloud (AWS + AZURE)"

echo "--> 1. Levantando la infraestructura en AWS (EKS, ECR, Secrets)..."
cd terraform/aws
terraform init
terraform apply -auto-approve 

echo "--> Extrayendo la IP y generando la llave SSH dinámica del orquestador..."
terraform output -raw jenkins_ssh_private_key > ../../ansible/jenkins_key.pem
chmod 400 ../../ansible/jenkins_key.pem
JENKINS_IP=$(terraform output -raw jenkins_server_ip)
echo "IP del Orquestador Central (AWS EC2) obtenida: $JENKINS_IP"

# Regresamos a la raíz
cd ../../

# Despliegue en Azure

echo "--> 2. Levantando la infraestructura en Azure (AKS, ACR, Key Vault)..."
cd terraform/azure
terraform init
terraform apply -auto-approve 

# Regresamos a la raíz
cd ../../

# Orquestancion con ansible para instalar Jenkins y Docker en la EC2 de AWS
echo "--> 3. Generando el inventario de Ansible al vuelo..."
cd ansible
cat <<EOF > inventory.ini
[jenkins_server]
$JENKINS_IP ansible_user=ubuntu ansible_ssh_private_key_file=./jenkins_key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "--> 4. Aprovisionando el Orquestador central con Ansible..."
# Se ejecuta el playbook usando el inventario recién creado para instalar Jenkins y Docker
ansible-playbook -i inventory.ini playbook.yml

echo "==================================================="
echo "Despliegue multicloud completado con éxito!"
echo "🌐 Interfaz de Jenkins disponible en: http://$JENKINS_IP:8080"
echo "==================================================="

echo "Extrayendo URLs dinámicas de Terraform..."
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

echo "Archivo infra.env generado exitosamente con los mapeos automáticos."
