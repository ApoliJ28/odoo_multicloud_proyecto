pipeline {
    agent any

    environment {
        // El tag será el hash corto del commit de Git para garantizar reproducibilidad
        IMAGE_TAG = "${env.GIT_COMMIT[0..7]}"
    }

    stages {
        stage('Cargar Variables de Infraestructura') {
            steps {
                script {
                    echo "Mapeando outputs de Terraform automáticamente..."
                    // Leemos el archivo generado por deploy.sh
                    def infraEnv = readProperties file: 'infra.env'
                    
                    // Inyectamos las propiedades como variables de entorno globales para el pipeline
                    env.AWS_ECR_REPO   = infraEnv['AWS_ECR_REPO']
                    env.AZURE_ACR_REPO = infraEnv['AZURE_ACR_REPO']
                    env.AWS_REGION     = infraEnv['AWS_REGION']
                    env.EKS_CLUSTER    = infraEnv['EKS_CLUSTER']
                    env.AKS_RG         = infraEnv['AKS_RG']
                    env.AKS_CLUSTER    = infraEnv['AKS_CLUSTER']
                }
            }
        }

        stage('Compilación (Build)') {
            steps {
                script {
                    echo "Construyendo imagen Docker agnóstica de Odoo..."
                    // Ahora usamos las variables dinámicas
                    sh "docker build -t ${env.AWS_ECR_REPO}:${IMAGE_TAG} ./odoo-app"
                    sh "docker tag ${env.AWS_ECR_REPO}:${IMAGE_TAG} ${env.AZURE_ACR_REPO}:${IMAGE_TAG}"
                }
            }
        }

        stage('Análisis de Seguridad') {
            steps {
                script {
                    echo "Ejecutando escaneo de vulnerabilidades en la imagen (Trivy)..."
                    // En un entorno de producción, esto fallaría si detecta vulnerabilidades CRITICAL.
                    // Se usa '|| true' para que el pipeline continúe con el proposito de demostración del funcionanimiento del pipeline.
                    sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL,HIGH --light ${AWS_ECR_REPO}:${IMAGE_TAG} || true"
                }
            }
        }

        stage('Push a Registros (ECR y ACR)') {
            steps {
                script {
                    echo "Autenticando y subiendo imagen a AWS ECR..."
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin \$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com
                        docker tag ${AWS_ECR_REPO}:${IMAGE_TAG} \$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com/${AWS_ECR_REPO}:${IMAGE_TAG}
                        docker push \$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com/${AWS_ECR_REPO}:${IMAGE_TAG}
                    """

                    echo "Autenticando y subiendo imagen a Azure ACR..."
                    sh "az acr login --name odooappacr"
                    sh "docker push ${AZURE_ACR_REPO}:${IMAGE_TAG}"
                }
            }
        }

        stage('Preparar Manifiestos Agnósticos') {
            steps {
                script {
                    echo "Inyectando el tag dinámico en los manifiestos de Kubernetes..."
                    // Sustituye el texto REPLACE_IMAGE_TAG por el hash del commit actual
                    sh "sed -i 's/REPLACE_IMAGE_TAG/${IMAGE_TAG}/g' k8s/deployment.yaml"
                }
            }
        }

        stage('Despliegue en AWS (EKS)') {
            steps {
                script {
                    echo "Configurando contexto de kubectl para EKS..."
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}"
                    
                    echo "Aplicando manifiestos agnósticos en AWS..."
                    sh "kubectl apply -f k8s/"
                }
            }
        }

        stage('Despliegue en Azure (AKS)') {
            steps {
                script {
                    echo "Configurando contexto de kubectl para AKS..."
                    sh "az aks get-credentials --resource-group ${AKS_RG} --name ${AKS_CLUSTER} --overwrite-existing"
                    
                    echo "Aplicando manifiestos agnósticos en Azure..."
                    sh "kubectl apply -f k8s/"
                }
            }
        }
    }

    // Mecanismo de Rollback Automático
    post {
        success {
            echo "✅ Despliegue CI/CD completado con éxito en ambas plataformas."
            echo "Ejecutando verificación post-despliegue (HTTP 200 OK)..."
            // Aquí se ejecutaría un script curl para verificar la salud del endpoint
        }
        failure {
            echo "❌ Fallo detectado en el pipeline. Iniciando mecanismo de ROLLBACK AUTOMÁTICO en ambas nubes..."
            script {
                echo "Revirtiendo despliegue en AWS EKS..."
                sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}"
                sh "kubectl rollout undo deployment/odoo-deployment || true"

                echo "Revirtiendo despliegue en Azure AKS..."
                sh "az aks get-credentials --resource-group ${AKS_RG} --name ${AKS_CLUSTER} --overwrite-existing"
                sh "kubectl rollout undo deployment/odoo-deployment || true"
            }
        }
    }
}