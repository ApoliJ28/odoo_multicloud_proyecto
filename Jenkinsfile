pipeline {
    agent any
    //coment push.
    environment {
        // El tag será el hash corto del commit de Git
        IMAGE_TAG = "${env.GIT_COMMIT[0..7]}"
    }

    stages {
        stage('1. Cargar Variables de Infraestructura') {
            steps {
                script {
                    echo "Mapeando outputs de Terraform automáticamente..."
                    // Funciona gracias al plugin pipeline-utility-steps
                    def infraEnv = readProperties file: 'infra.env'
                    
                    env.AWS_ECR_REPO   = infraEnv['AWS_ECR_REPO']
                    env.AZURE_ACR_REPO = infraEnv['AZURE_ACR_REPO']
                    env.AWS_REGION     = infraEnv['AWS_REGION']
                    env.EKS_CLUSTER    = infraEnv['EKS_CLUSTER']
                    env.AKS_RG         = infraEnv['AKS_RG']
                    env.AKS_CLUSTER    = infraEnv['AKS_CLUSTER']
                }
            }
        }

        stage('2. Compilación (Build)') {
            steps {
                script {
                    echo "Construyendo imagen Docker agnóstica de Odoo..."
                    sh "docker build -t ${env.AWS_ECR_REPO}:${IMAGE_TAG} ./odoo-app"
                    sh "docker tag ${env.AWS_ECR_REPO}:${IMAGE_TAG} ${env.AZURE_ACR_REPO}:${IMAGE_TAG}"
                }
            }
        }

        stage('3. Análisis de Seguridad') {
            steps {
                script {
                    echo "Ejecutando escaneo de vulnerabilidades (Trivy)..."
                    sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL,HIGH --light ${env.AWS_ECR_REPO}:${IMAGE_TAG} || true"
                }
            }
        }

        stage('3.5 Aprovisionamiento de Secretos en K8s') {
            steps {
                script {
                    def secretCreds = [
                        dbHost: 'db-host-cred', dbUser: 'db-user-cred',
                        dbPass: 'db-pass-cred', adminPass: 'admin-pass-cred',
                        dbName: 'db-name-cred'
                        
                    ]

                    // 1. PRIMERO: Aplicar secretos en AWS (con credenciales AWS)
                    withCredentials([
                        aws(credentialsId: 'aws-credentials-id'),
                        string(credentialsId: 'aws-session-token', variable: 'AWS_SESSION_TOKEN'),
                        string(credentialsId: secretCreds.dbHost, variable: 'DB_HOST'),
                        string(credentialsId: secretCreds.dbUser, variable: 'DB_USER'),
                        string(credentialsId: secretCreds.dbPass, variable: 'DB_PASSWORD'),
                        string(credentialsId: secretCreds.adminPass, variable: 'ADMIN_PASSWORD'),
                        string(credentialsId: secretCreds.dbName, variable: 'DB_NAME')
                    ]) {
                        echo "Aplicando secretos en AWS EKS..."
                        sh "aws eks update-kubeconfig --region ${env.AWS_REGION} --name ${env.EKS_CLUSTER}"
                        sh """
                            kubectl delete secret odoo-db-secrets --ignore-not-found
                            kubectl create secret generic odoo-db-secrets \
                                --from-literal=db_host=$DB_HOST \
                                --from-literal=db_user=$DB_USER \
                                --from-literal=db_password=$DB_PASSWORD \
                                --from-literal=admin_password=$ADMIN_PASSWORD \
                                --from-literal=db_name=$DB_NAME
                        """
                    }

                    // 2. SEGUNDO: Aplicar secretos en Azure (con credenciales Azure)
                    withCredentials([
                        azureServicePrincipal('azure-credentials-id'),
                        string(credentialsId: secretCreds.dbHost, variable: 'DB_HOST'),
                        string(credentialsId: secretCreds.dbUser, variable: 'DB_USER'),
                        string(credentialsId: secretCreds.dbPass, variable: 'DB_PASSWORD'),
                        string(credentialsId: secretCreds.adminPass, variable: 'ADMIN_PASSWORD'),
                        string(credentialsId: secretCreds.dbName, variable: 'DB_NAME')
                    ]) {
                        echo "Aplicando secretos en Azure AKS..."
                        sh "az login --service-principal -u \$AZURE_CLIENT_ID -p \$AZURE_CLIENT_SECRET --tenant \$AZURE_TENANT_ID"
                        sh "az aks get-credentials --resource-group ${env.AKS_RG} --name ${env.AKS_CLUSTER} --overwrite-existing"
                        sh """
                            kubectl delete secret odoo-db-secrets --ignore-not-found
                            kubectl create secret generic odoo-db-secrets \
                                --from-literal=db_host=$DB_HOST \
                                --from-literal=db_user=$DB_USER \
                                --from-literal=db_password=$DB_PASSWORD \
                                --from-literal=admin_password=$ADMIN_PASSWORD \
                                --from-literal=db_name=$DB_NAME
                        """
                    }
                }
            }
        }

        stage('4. Push a Registros (ECR y ACR)') {
            steps {
                script {
                    // AUTENTICACIÓN AWS ECR usando el ID que inyectamos con Ansible
                    withCredentials([
                        aws(credentialsId: 'aws-credentials-id'),
                        string(credentialsId: 'aws-session-token', variable: 'AWS_SESSION_TOKEN')
                    ]) {
                        echo "Autenticando en AWS ECR con soporte temporal STS..."
                        sh """
                            aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.AWS_ECR_REPO}
                            docker push ${env.AWS_ECR_REPO}:${IMAGE_TAG}
                        """
                    }

                    // AUTENTICACIÓN AZURE ACR usando el Service Principal de Ansible
                    withCredentials([azureServicePrincipal('azure-credentials-id')]) {
                        echo "Autenticando y subiendo imagen a Azure ACR..."
                        sh """
                            az login --service-principal -u \$AZURE_CLIENT_ID -p \$AZURE_CLIENT_SECRET --tenant \$AZURE_TENANT_ID
                            
                            ACR_NAME=\$(echo ${env.AZURE_ACR_REPO} | cut -d'.' -f1)

                            # Iniciar sesión en el registro de ACR
                            az acr login --name \$ACR_NAME
                            
                            docker push ${env.AZURE_ACR_REPO}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }

        stage('5. Despliegue en AWS (EKS)') {
            steps {
                script {
                    withCredentials([
                        aws(credentialsId: 'aws-credentials-id'),
                        string(credentialsId: 'aws-session-token', variable: 'AWS_SESSION_TOKEN')
                    ]) {
                        echo "Configurando contexto de kubectl para AWS EKS..."
                        sh "aws eks update-kubeconfig --region ${env.AWS_REGION} --name ${env.EKS_CLUSTER}"
                        
                        echo "Inyectando imagen de ECR y desplegando en AWS..."
                        // Hacemos una copia temporal de los manifiestos para no manchar el repo local
                        sh "mkdir -p k8s-aws && cp k8s/* k8s-aws/"
                        sh "sed -i 's|REPLACE_IMAGE_TAG|${env.AWS_ECR_REPO}:${IMAGE_TAG}|g' k8s-aws/deployment.yaml"
                        sh "sed -i 's|REPLACE_IMAGE_TAG|${env.AWS_ECR_REPO}:${IMAGE_TAG}|g' k8s-aws/odoo-upgrade-job.yaml"
                        
                        // Paso 0: Instalar AWS Load Balancer Controller (requerido en EKS para type: LoadBalancer)
                        echo "Paso 0/3: Verificando AWS Load Balancer Controller..."
                        sh """
                            if ! kubectl get deployment -n kube-system aws-load-balancer-controller --no-headers 2>/dev/null | grep -q aws-load-balancer-controller; then
                                echo "Instalando AWS Load Balancer Controller..."
                                
                                # 1. Instalar cert-manager (prerequisito para webhooks del controlador)
                                kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.7/cert-manager.yaml
                                echo "Esperando a que cert-manager esté listo..."
                                kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=180s
                                
                                # 2. Descargar manifiesto del AWS Load Balancer Controller
                                curl -Lo /tmp/v2_7_2_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml
                                
                                # 3. Configurar el nombre del clúster en el manifiesto
                                sed -i 's|your-cluster-name|${env.EKS_CLUSTER}|g' /tmp/v2_7_2_full.yaml
                                
                                # 4. Eliminar la anotación de IRSA (usamos el rol del nodo LabRole)
                                sed -i '/eks.amazonaws.com\\/role-arn/d' /tmp/v2_7_2_full.yaml
                                
                                # 5. Aplicar
                                kubectl apply -f /tmp/v2_7_2_full.yaml
                                echo "Esperando a que el controlador esté listo..."
                                kubectl wait --for=condition=Available deployment/aws-load-balancer-controller -n kube-system --timeout=180s
                                
                                echo "AWS Load Balancer Controller instalado exitosamente."
                            else
                                echo "AWS Load Balancer Controller ya está instalado."
                            fi
                        """
                        
                        // Paso 1: Desplegar PostgreSQL y Servicio primero
                        echo "Paso 1/3: Desplegando PostgreSQL y Servicios..."
                        sh "kubectl apply -f k8s-aws/postgres.yaml -f k8s-aws/service.yaml"
                        // Inyectar anotaciones NLB para que el AWS Load Balancer Controller cree un Network Load Balancer
                        sh """
                            kubectl annotate svc odoo-service --overwrite \
                                service.beta.kubernetes.io/aws-load-balancer-type=external \
                                service.beta.kubernetes.io/aws-load-balancer-nlb-target-type=ip \
                                service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing
                        """
                        sh "kubectl rollout status deployment/postgres-deployment --timeout=120s"
                        
                        // Paso 2: Ejecutar Job de inicialización de BD y esperar a que termine
                        echo "Paso 2/3: Inicializando base de datos con el Job..."
                        sh "kubectl delete job odoo-upgrade-job --ignore-not-found"
                        sh "kubectl apply -f k8s-aws/odoo-upgrade-job.yaml"
                        sh "kubectl wait --for=condition=complete job/odoo-upgrade-job --timeout=300s"
                        
                        // Paso 3: Desplegar Odoo (la BD ya está lista)
                        echo "Paso 3/3: Desplegando Odoo..."
                        sh "kubectl apply -f k8s-aws/deployment.yaml"
                    }
                }
            }
        }

        stage('6. Despliegue en Azure (AKS)') {
            steps {
                script {
                    withCredentials([azureServicePrincipal('azure-credentials-id')]) {
                        echo "Configurando contexto de kubectl para Azure AKS..."
                        sh "az login --service-principal -u \$AZURE_CLIENT_ID -p \$AZURE_CLIENT_SECRET --tenant \$AZURE_TENANT_ID"
                        sh "az aks get-credentials --resource-group ${env.AKS_RG} --name ${env.AKS_CLUSTER} --overwrite-existing"
                        
                        echo "Inyectando imagen de ACR y desplegando en Azure..."
                        sh "mkdir -p k8s-azure && cp k8s/* k8s-azure/"
                        sh "sed -i 's|REPLACE_IMAGE_TAG|${env.AZURE_ACR_REPO}:${IMAGE_TAG}|g' k8s-azure/deployment.yaml"
                        sh "sed -i 's|REPLACE_IMAGE_TAG|${env.AZURE_ACR_REPO}:${IMAGE_TAG}|g' k8s-azure/odoo-upgrade-job.yaml"
                        
                        echo "Creando secreto para que AKS pueda descargar la imagen de ACR..."
                        sh """
                            ACR_SERVER=\$(echo ${env.AZURE_ACR_REPO} | cut -d'/' -f1)
                            kubectl delete secret acr-secret --ignore-not-found
                            kubectl create secret docker-registry acr-secret \\
                                --docker-server=\$ACR_SERVER \\
                                --docker-username=\$AZURE_CLIENT_ID \\
                                --docker-password=\$AZURE_CLIENT_SECRET
                            
                            awk '/containers:/ { print "      imagePullSecrets:\\n      - name: acr-secret"; print; next }1' k8s-azure/deployment.yaml > tmp.yaml && mv tmp.yaml k8s-azure/deployment.yaml
                            awk '/containers:/ { print "      imagePullSecrets:\\n      - name: acr-secret"; print; next }1' k8s-azure/odoo-upgrade-job.yaml > tmp.yaml && mv tmp.yaml k8s-azure/odoo-upgrade-job.yaml
                        """
                        
                        // Paso 1: Desplegar PostgreSQL y Servicio primero
                        echo "Paso 1/3: Desplegando PostgreSQL y Servicios..."
                        sh "kubectl apply -f k8s-azure/postgres.yaml -f k8s-azure/service.yaml"
                        sh "kubectl rollout status deployment/postgres-deployment --timeout=120s"
                        
                        // Paso 2: Ejecutar Job de inicialización de BD y esperar a que termine
                        echo "Paso 2/3: Inicializando base de datos con el Job..."
                        sh "kubectl delete job odoo-upgrade-job --ignore-not-found"
                        sh "kubectl apply -f k8s-azure/odoo-upgrade-job.yaml"
                        sh "kubectl wait --for=condition=complete job/odoo-upgrade-job --timeout=300s"
                        
                        // Paso 3: Desplegar Odoo (la BD ya está lista)
                        echo "Paso 3/3: Desplegando Odoo..."
                        sh "kubectl apply -f k8s-azure/deployment.yaml"
                    }
                }
            }
        }

        stage('7. Obtener Endpoints de Acceso') {
            steps {
                script {
                    echo "------------------------------------------------"
                    echo "🌐 BUSCANDO ENDPOINTS DE ACCESO..."
                    echo "------------------------------------------------"
                    
                    // AWS EKS
                    withCredentials([
                        aws(credentialsId: 'aws-credentials-id'),
                        string(credentialsId: 'aws-session-token', variable: 'AWS_SESSION_TOKEN')
                    ]) {
                        sh "aws eks update-kubeconfig --region ${env.AWS_REGION} --name ${env.EKS_CLUSTER}"
                        echo "Endpoint AWS (EKS):"
                        sh "kubectl get svc odoo-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
                        echo ""
                    }

                    // Azure AKS
                    withCredentials([azureServicePrincipal('azure-credentials-id')]) {
                        sh "az login --service-principal -u \$AZURE_CLIENT_ID -p \$AZURE_CLIENT_SECRET --tenant \$AZURE_TENANT_ID"
                        sh "az aks get-credentials --resource-group ${env.AKS_RG} --name ${env.AKS_CLUSTER} --overwrite-existing"
                        echo "Endpoint Azure (AKS):"
                        sh "kubectl get svc odoo-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
                        echo ""
                    }
                    echo "------------------------------------------------"
                }
            }
        }
    
    }
    

    // Mecanismo de Rollback Automático
    post {
        success {
            echo "✅ ¡DESPLIEGUE MULTICLOUD EXITOSO EN AWS Y AZURE!"
        }
        failure {
            echo "❌ Fallo detectado en el pipeline. Iniciando ROLLBACK AUTOMÁTICO..."
            script {
                // Solo intenta hacer rollback si las variables de entorno lograron cargarse en el paso 1
                if (env.AWS_REGION != null) {
                    withCredentials([
                        aws(credentialsId: 'aws-credentials-id'),
                        string(credentialsId: 'aws-session-token', variable: 'AWS_SESSION_TOKEN')
                    ]) {
                        echo "Revirtiendo AWS EKS..."
                        sh "aws eks update-kubeconfig --region ${env.AWS_REGION} --name ${env.EKS_CLUSTER} || true"
                        sh "kubectl rollout undo deployment/odoo-deployment || true"
                    }
                    withCredentials([azureServicePrincipal('azure-credentials-id')]) {
                        echo "Revirtiendo Azure AKS..."
                        sh "az login --service-principal -u \$AZURE_CLIENT_ID -p \$AZURE_CLIENT_SECRET --tenant \$AZURE_TENANT_ID || true"
                        sh "az aks get-credentials --resource-group ${env.AKS_RG} --name ${env.AKS_CLUSTER} --overwrite-existing || true"
                        sh "kubectl rollout undo deployment/odoo-deployment || true"
                    }
                } else {
                    echo "⚠️ Fallo antes de cargar variables de nube. Rollback de K8s omitido."
                }
            }
        }
    }
}