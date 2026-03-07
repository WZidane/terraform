import os
import json
import uuid
from common import response, dynamodb, validate_token, extract_token_from_event

polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE', 'Polls'))


def lambda_handler(event, context):
    method = event.get('requestContext', {}).get('http', {}).get('method')
    path = (event.get('rawPath') or event.get('path') or '').rstrip('/')

    # GET /polls
    if method == 'GET' and path.endswith('/polls'):
        resp = polls_table.scan()
        return response(200, resp.get('Items', []))

    # POST /polls (protégé)
    if method == 'POST' and path.endswith('/polls'):
        token = extract_token_from_event(event)
        ok, info = validate_token(token, os.environ.get('COGNITO_REGION', 'eu-north-1'), os.environ.get('COGNITO_USER_POOL_ID'))
        if not ok:
            return response(401, {'error': 'Unauthorized', 'details': info})

        body = event.get('body') or '{}'
        try:
            data = json.loads(body)
        except Exception:
            return response(400, {'error': 'invalid json'})

        name = data.get('name')
        if not name:
            return response(400, {'error': "'name' is required"})

        poll_id = str(uuid.uuid4())
        item = {'id': poll_id, 'name': name}
        polls_table.put_item(Item=item)
        return response(201, item)

    return response(404, {'error': 'not found'})
