import os
import json
import uuid
from common import response, dynamodb

votes_table = dynamodb.Table(os.environ.get('VOTES_TABLE', 'Votes'))
polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE', 'Polls'))

def lambda_handler(event, context):
    method = event.get('requestContext', {}).get('http', {}).get('method')
    
    # Récupération du sub via l'Authorizer
    try:
        user_id = event['requestContext']['authorizer']['jwt']['claims']['sub']
    except KeyError:
        return response(401, {'error': 'Unauthorized'})

    if method == 'POST':
        body = json.loads(event.get('body', '{}'))
        candidate_id = body.get('candidate_id')
        poll_id = body.get('poll_id')

        # Vérification minimale
        if not candidate_id or not poll_id:
            return response(400, {'error': 'Infos manquantes'})
            
        # Le candidate_id est le sub cognito du candidat
        vote_id = str(uuid.uuid4())
        item = {
            'id': vote_id, 
            'user_id': user_id, 
            'candidate_id': candidate_id, 
            'poll_id': poll_id
        }
        votes_table.put_item(Item=item)
        return response(201, item)

    return response(404, {'error': 'not found'})