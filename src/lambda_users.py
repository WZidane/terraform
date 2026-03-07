import os
import json
import uuid
from common import response, dynamodb, validate_token, extract_token_from_event

users_table = dynamodb.Table(os.environ.get('USERS_TABLE', 'Users'))


def lambda_handler(event, context):
    method = event.get('requestContext', {}).get('http', {}).get('method')
    path = (event.get('rawPath') or event.get('path') or '').rstrip('/')

    # GET /users
    if method == 'GET' and path.endswith('/users'):
        resp = users_table.scan()
        return response(200, resp.get('Items', []))

    # POST /users (protégé)
    if method == 'POST' and path.endswith('/users'):
        token = extract_token_from_event(event)
        ok, info = validate_token(token, os.environ.get('COGNITO_REGION', 'eu-north-1'), os.environ.get('COGNITO_USER_POOL_ID'))
        if not ok:
            return response(401, {'error': 'Unauthorized', 'details': info})

        body = event.get('body') or '{}'
        try:
            data = json.loads(body)
        except Exception:
            return response(400, {'error': 'invalid json'})

        username = data.get('username') or data.get('email') or 'unknown'
        user_id = str(uuid.uuid4())
        item = {'id': user_id, 'username': username}
        users_table.put_item(Item=item)
        return response(201, item)

    return response(404, {'error': 'not found'})
