FROM odoo:17.0

USER root

# Preparamos el directorio para los módulos personalizados (extra-addons)
RUN mkdir -p /mnt/extra-addons && chown -R odoo:odoo /mnt/extra-addons

# Se inyecta el script de configuración dinámica
COPY ./entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

USER odoo

ENTRYPOINT ["/custom-entrypoint.sh"]
CMD ["odoo"]
