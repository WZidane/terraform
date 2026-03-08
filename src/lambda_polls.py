import os
import json
import uuid
import boto3
from common import response, dynamodb

# Tables et Clients
polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE'))
app_table = dynamodb.Table(os.environ.get('APPLICATION_TABLE'))
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    method = event.get('httpMethod')
    path_params = event.get('pathParameters') or {}


    if not method and 'requestContext' in event:
        method = event['requestContext'].get('http', {}).get('method')

    authorizer = event.get('requestContext', {}).get('authorizer', {})
    
    claims = authorizer.get('claims', {})
    
    user_id = claims.get('sub') or authorizer.get('jwt', {}).get('claims', {}).get('sub') or authorizer.get('principalId')

    print(f"sub : {user_id}")
    
    # --- 1. ROUTE: GET /get-presigned-url ---
    if method == 'GET' and 'get-presigned-url' in path:
        file_name = event.get('queryStringParameters', {}).get('filename', str(uuid.uuid4()))
        try:
            url = s3_client.generate_presigned_url(
                'put_object',
                Params={
                    'Bucket': os.environ['BUCKET_NAME'],
                    'Key': f"candidatures/{file_name}"
                },
                ExpiresIn=300
            )
            return response(200, {'upload_url': url})
        except Exception as e:
            return response(500, {'error': str(e)})

    # --- 2. ROUTE: POST /application/{id}/{userId} ---
    # On utilise 'in path' car le rawPath contient les IDs réels
    if method == 'POST' and '/application/' in path:
        poll_id = path_params.get('id')
        if poll_id:
            # GET /polls/{id} -> récupérer un poll spécifique
            resp = polls_table.get_item(Key={'id': poll_id})
            item = resp.get('Item')
            if not item:
                return response(404, {'error': 'Poll not found'})
            return response(200, item)
        else:
            # lister tous les polls
            resp = polls_table.scan()
            return response(200, resp.get('Items', []))

    if method == 'POST':
        try:
            given_name = claims.get('given_name') or claims.get('custom:given_name', '')
            family_name = claims.get('family_name') or claims.get('custom:family_name', '')
            creator_name = f"{given_name} {family_name}".strip()

            body = json.loads(event.get('body', '{}'))
            name = body.get('name')
            if not name: return response(400, {'error': 'Name required'})
            
            if not name:
                return response(400, {'error': "l'attribut 'name' est requis"})

            if len(name) > 200:
                return response(400, {'error': "Le nom ne doit pas dépasser 200 caractères"})

            poll_id = str(uuid.uuid4())
            item = {'id': poll_id, 
                'name': name,
                'creator_name' : creator_name or "Anonyme", 
                'creator_id': user_id, 
                'is_active': True}
            polls_table.put_item(Item=item)

            return response(201, item)
        except Exception as e:
            return response(400, {'error': 'JSON invalide', 'details': str(e)})
    
    if method == 'PUT':
        poll_id = path_params.get('id')
        if not poll_id:
            return response(400, {'error': "L'attribut 'id' est requis pour fermer un poll"})

        if not user_id:
            return response(401, {'error': 'Utilisateur non authentifié'})
        
        resp = polls_table.get_item(Key={'id': poll_id})
        existing_poll = resp.get('Item')

        if not existing_poll:
            return response(404, {'error': "Sondage introuvable"})

        if not existing_poll.get('is_active'):
            return response(400, {'error': "Cette élection est déjà clôturée"})

        if existing_poll.get('creator_id') != user_id:
            return response(403, {'error': "Accès refusé : vous n'êtes pas le créateur de cette élection"})
        
        try:
            polls_table.update_item(
                Key={'id': poll_id},
                UpdateExpression="set is_active = :val",
                ExpressionAttributeValues={':val': False}
            )
            return response(200, {'message': f"Election merveilleusement cloturée !"})
        except Exception as e:
            return response(400, {'error': "Erreur lors de la cloture de l'élection", 'details': str(e)})

    # Si aucune route ne correspond
    return response(405, {'error': f'Method {method} not allowed on {path}'})