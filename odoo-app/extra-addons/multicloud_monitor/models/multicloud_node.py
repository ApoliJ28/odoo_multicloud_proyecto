from odoo import models, fields

class MulticloudNode(models.Model):
    _name = 'multicloud.node'
    _description = 'Nodo de Infraestructura Multicloud'

    name = fields.Char(string='Nombre del Nodo', required=True)
    cloud_provider = fields.Selection([
        ('aws', 'Amazon Web Services (EKS)'),
        ('azure', 'Microsoft Azure (AKS)')
    ], string='Proveedor Cloud', required=True)
    ip_address = fields.Char(string='Dirección IP')
    status = fields.Selection([
        ('running', 'En ejecución'),
        ('stopped', 'Detenido'),
        ('error', 'Error')
    ], string='Estado', default='running')