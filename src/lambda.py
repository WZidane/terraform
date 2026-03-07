import json
import boto3
import os
import uuid
import base64
import time
import requests
from jose import jwk, jwt
from jose.utils import base64url_decode

# Initialisation du client DynamoDB
dynamodb = boto3.resource('dynamodb')


def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            # Ce fichier est désormais un wrapper minimal. Les handlers spécifiques se trouvent dans lambda_users.py, lambda_polls.py et lambda_votes.py
            def lambda_handler(event, context):
                return {
                    'statusCode': 200,
                    'body': json.dumps({'message': 'Use specific lambda_{users|polls|votes} handlers'})
                }
                return response(400, { 'error': "'poll_id' is required" })

            # user_id = sub from token
            user_id = info.get('sub') if isinstance(info, dict) else (info.get('sub') if hasattr(info,'get') else None)
            if not user_id:
                return response(401, { 'error': 'Invalid token: missing sub' })

            # verify candidate exists
            cand_resp = users_table.get_item(Key={'id': candidate_id})
            if 'Item' not in cand_resp:
                return response(400, { 'error': 'candidate_id not found' })

            # verify poll exists
            poll_resp = polls_table.get_item(Key={'id': poll_id})
            if 'Item' not in poll_resp:
                return response(400, { 'error': 'poll_id not found' })

            vote_id = str(uuid.uuid4())
            item = { 'id': vote_id, 'user_id': user_id, 'candidate_id': candidate_id, 'poll_id': poll_id }
            votes_table.put_item(Item=item)
            return response(201, item)

        # Route non trouvée
        return response(404, {"error": "Not found"})

    except Exception as e:
        print("Erreur:", str(e))
        return response(500, {"error": "Internal server error"})