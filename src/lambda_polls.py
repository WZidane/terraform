import os
import json
import uuid
from common import response, dynamodb

# On récupère la table via la variable d'env définie dans Terraform
polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE', 'Polls'))

def lambda_handler(event, context):
    print("Event reçu:", json.dumps(event))
    method = event.get('httpMethod')
    if not method and 'requestContext' in event:
        method = event['requestContext'].get('http', {}).get('method')
    
    print(f"Méthode HTTP détectée: {method}")
    
    if method == 'GET':
        resp = polls_table.scan()
        return response(200, resp.get('Items', []))

    if method == 'POST':
        try:
            body = json.loads(event.get('body', '{}'))
            name = body.get('name')
            
            if not name:
                return response(400, {'error': "l'attribut 'name' est requis"})

            if len(name) > 200:
                return response(400, {'error': "Le nom ne doit pas dépasser 200 caractères"})

            poll_id = str(uuid.uuid4())
            item = {'id': poll_id, 'name': name}
            polls_table.put_item(Item=item)
            return response(201, item)
        except Exception as e:
            return response(400, {'error': 'JSON invalide', 'details': str(e)})


    return response(405, {'error': f'Methode {method} non autorisée sur cette ressource'})