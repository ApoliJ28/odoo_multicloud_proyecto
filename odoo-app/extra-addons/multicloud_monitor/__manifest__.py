{
    'name': 'Gestor de Nodos Multicloud',
    'version': '1.0',
    'category': 'IT/Infrastructure',
    'summary': 'Módulo personalizado para monitorizar nodos de AWS y Azure',
    'description': """
        Este es un módulo de prueba para verificar el despliegue CI/CD.
        Permite registrar instancias y clústeres desplegados en AWS EKS y Azure AKS.
    """,
    'author': 'Team UNIR',
    'depends': ['base'],
    'data': [
        'security/ir.model.access.csv',
        'views/multicloud_node_views.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
}