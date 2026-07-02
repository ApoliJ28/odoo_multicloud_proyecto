FROM odoo:17.0

USER root

# Preparamos el directorio para los módulos personalizados (extra-addons)
RUN mkdir -p /mnt/extra-addons 

# Copiar el código de tus módulos personalizados dentro de la imagen
COPY ./extra-addons /mnt/extra-addons

RUN chown -R odoo:odoo /mnt/extra-addons

# Se inyecta el script de configuración dinámica
COPY ./entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

USER odoo

ENTRYPOINT ["/custom-entrypoint.sh"]
CMD ["odoo"]
