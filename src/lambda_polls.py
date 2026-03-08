import os
import json
import uuid
import boto3
from boto3.dynamodb.conditions import Key
from collections import defaultdict
from common import response, dynamodb

# Tables et Clients
polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE'))
applications_table = dynamodb.Table(os.environ.get("APPLICATIONS_TABLE"))
votes_table = dynamodb.Table(os.environ.get("VOTES_TABLE"))
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    method = event.get('httpMethod')
    path = event.get('rawPath') or event.get('path') or ""
    path_params = event.get('pathParameters') or {}

    request_context = event.get('requestContext', {})

    method = (
        request_context.get('http', {}).get('method') or 
        event.get('httpMethod') or 
        request_context.get('method')
    )

    authorizer = event.get('requestContext', {}).get('authorizer', {})
    
    claims = authorizer.get('claims', {})
    
    user_id = claims.get('sub') or authorizer.get('jwt', {}).get('claims', {}).get('sub') or authorizer.get('principalId')

    print(f"sub : {user_id}")

    if method == 'GET':
        poll_id = path_params.get('id')
        if poll_id:
            resp = polls_table.get_item(Key={'id': poll_id})
            item = resp.get('Item')
            return response(200, item) if item else response(404, {'error': 'Not found'})
        else:
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
        
        counts = defaultdict(int)

        rep = votes_table.query(
            KeyConditionExpression=Key("poll_id").eq(poll_id)
        )

        while True:
            for item in rep["Items"]:
                counts[item["candidate_id"]] += 1

            if "LastEvaluatedKey" not in rep:
                break

            rep = votes_table.query(
                KeyConditionExpression=Key("poll_id").eq(poll_id),
                ExclusiveStartKey=rep["LastEvaluatedKey"]
            )

        for candidate_id, vote_count in counts.items():

            applications_table.update_item(
                Key={"user_id": candidate_id},
                UpdateExpression="SET votes = :v",
                ExpressionAttributeValues={
                    ":v": vote_count
                }
            )

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