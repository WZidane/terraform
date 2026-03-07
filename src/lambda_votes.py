import os
import json
import uuid
from common import response, dynamodb, validate_token, extract_token_from_event

votes_table = dynamodb.Table(os.environ.get('VOTES_TABLE', 'Votes'))
users_table = dynamodb.Table(os.environ.get('USERS_TABLE', 'Users'))
polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE', 'Polls'))


def lambda_handler(event, context):
    method = event.get('requestContext', {}).get('http', {}).get('method')
    path = (event.get('rawPath') or event.get('path') or '').rstrip('/')

    # GET /votes
    if method == 'GET' and path.endswith('/votes'):
        resp = votes_table.scan()
        return response(200, resp.get('Items', []))

    # POST /votes (protégé)
    if method == 'POST' and path.endswith('/votes'):
        token = extract_token_from_event(event)
        ok, info = validate_token(token, os.environ.get('COGNITO_REGION', 'eu-north-1'), os.environ.get('COGNITO_USER_POOL_ID'))
        if not ok:
            return response(401, {'error': 'Unauthorized', 'details': info})

        body = event.get('body') or '{}'
        try:
            data = json.loads(body)
        except Exception:
            return response(400, {'error': 'invalid json'})

        candidate_id = data.get('candidate_id')
        poll_id = data.get('poll_id')
        if not candidate_id:
            return response(400, {'error': "'candidate_id' is required"})
        if not poll_id:
            return response(400, {'error': "'poll_id' is required"})

        # user_id = sub from token
        user_id = info.get('sub') if isinstance(info, dict) else None
        if not user_id:
            return response(401, {'error': 'Invalid token: missing sub'})

        # verify candidate exists
        cand_resp = users_table.get_item(Key={'id': candidate_id})
        if 'Item' not in cand_resp:
            return response(400, {'error': 'candidate_id not found'})

        # verify poll exists
        poll_resp = polls_table.get_item(Key={'id': poll_id})
        if 'Item' not in poll_resp:
            return response(400, {'error': 'poll_id not found'})

        vote_id = str(uuid.uuid4())
        item = {'id': vote_id, 'user_id': user_id, 'candidate_id': candidate_id, 'poll_id': poll_id}
        votes_table.put_item(Item=item)
        return response(201, item)

    return response(404, {'error': 'not found'})
