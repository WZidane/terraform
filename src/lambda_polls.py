import os
import json
import uuid
from common import response, dynamodb

polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE', 'Polls'))

def lambda_handler(event, context):
    method = event.get('requestContext', {}).get('http', {}).get('method')
    
    # GET /polls : Tout le monde peut voir les sondages
    if method == 'GET':
        resp = polls_table.scan()
        return response(200, resp.get('Items', []))

    # POST /polls : Seul un utilisateur connecté peut créer un sondage
    if method == 'POST':
        # L'Authorizer garantit que l'utilisateur est valide
        body = json.loads(event.get('body', '{}'))
        name = body.get('name')
        
        if not name:
            return response(400, {'error': "'name' est requis"})

        poll_id = str(uuid.uuid4())
        item = {'id': poll_id, 'name': name}
        polls_table.put_item(Item=item)
        return response(201, item)

    return response(404, {'error': 'not found'})