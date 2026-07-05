#!/bin/bash
set -e

echo "Generando archivo de configuración odoo.conf desde variables de entorno..."

cat <<EOF > /etc/odoo/odoo.conf
[options]
admin_passwd = ${ODOO_ADMIN_PASSWORD:-admin}
db_host = ${DB_HOST:-localhost}
db_port = ${DB_PORT:-5432}
db_user = ${DB_USER:-odoo}
db_password = ${DB_PASSWORD:-odoo}
db_name = ${DB_NAME:-odoo_produccion}
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo
list_db = False
proxy_mode = True
EOF

echo "Configuración generada exitosamente."

# Pasa el control al entrypoint original de la imagen base
exec /entrypoint.sh "$@"
