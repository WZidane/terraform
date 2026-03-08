import os
import json
import uuid
import boto3
from common import response, dynamodb

votes_table = dynamodb.Table(os.environ.get('VOTES_TABLE', 'Votes'))
polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE', 'Polls'))
applications_table = dynamodb.Table(os.environ.get('APPLICATIONS_TABLE', 'Applications'))

def lambda_handler(event, context):
    method = event.get('httpMethod')
    
    # Récupération du sub via l'Authorizer
    authorizer = event.get('requestContext', {}).get('authorizer', {})
    
    claims = authorizer.get('claims', {})
    
    user_id = claims.get('sub') or authorizer.get('jwt', {}).get('claims', {}).get('sub') or authorizer.get('principalId')

    if method == 'POST':
        print("bonjour cv")
        body = json.loads(event.get('body', '{}'))
        poll_id = body.get('poll_id')
        candidate_user_id = body.get('candidateUserId')

        print(f"poll_id: {poll_id}, user_id: {user_id}, candidate_user_id: {candidate_user_id}")

        if not poll_id or not candidate_user_id:
            return response(400, {'error': 'Infos manquantes'})

        resp = polls_table.get_item(Key={'id': poll_id})
        existing_poll = resp.get('Item')

        print(f"existing_poll: {existing_poll}")

        resp2 = applications_table.get_item(
            Key={
                'poll_id': poll_id,
                'user_id': candidate_user_id
            }
        )
        existing_application = resp2.get('Item')

        print(f"existing_application: {existing_application}")

        if not existing_application:
            return response(404, {'error': "Candidature introuvable"})

        if not existing_poll:
            return response(404, {'error': "Sondage introuvable"})

        if not existing_poll.get('is_active'):
            return response(400, {'error': "Cette élection est déjà clôturée"})

        resp3 = votes_table.query(
            IndexName='UserIndex',
            KeyConditionExpression=boto3.dynamodb.conditions.Key('user_id').eq(user_id) & 
                                   boto3.dynamodb.conditions.Key('poll_id').eq(poll_id)
        )
        existing_votes = resp3.get('Items', [])

        if len(existing_votes) > 0:
            return response(400, {'error': "Vous avez déjà voté dans ce sondage"})

        vote_id = str(uuid.uuid4())
        item = {
            'id': vote_id, 
            'user_id': user_id,  
            'poll_id': poll_id,
            'candidate_id': candidate_user_id
        }
        votes_table.put_item(Item=item)

        return response(201, item)

    return response(404, {'error': 'not found'})