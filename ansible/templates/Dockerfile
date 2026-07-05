FROM jenkins/jenkins:lts

# Cambiamos a usuario root para tener permisos de instalación
USER root

# Instalar dependencias básicas y limpiar caché de apt AL INSTANTE
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    gnupg \
    lsb-release \
    sudo \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Instalar Docker CLI (Copiando el binario oficial)
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker

# Instalar AWS CLI v2 (Descargar, instalar y BORRAR el zip en la misma instrucción)
RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip ./aws /usr/local/aws-cli/v2/*/dist/aws_completer

# Instalar Azure CLI (az) y limpiar la basura temporal de apt en la misma línea
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Instalar Kubectl (Cliente oficial de Kubernetes)
RUN curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl

# Asegurar permisos y grupo de Docker para el usuario jenkins
RUN groupadd -f docker && usermod -aG docker jenkins

# Regresamos al usuario jenkins e instalamos los plugins
USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt