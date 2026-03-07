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
    print("Event:", json.dumps(event))

    request_context = event.get('requestContext', {})
    
    method = (
        request_context.get('http', {}).get('method') or 
        event.get('httpMethod') or 
        request_context.get('method')
    )
    
    path = event.get('rawPath') or event.get('path') or ""
    path_params = event.get('pathParameters') or {}
    
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
        user_id = path_params.get('userId')
        body = json.loads(event.get('body', '{}'))
        
        item = {
            'id': str(uuid.uuid4()),
            'poll_id': poll_id,
            'user_id': user_id,
            'document_id': body.get('document_id'),
            'status': 'pending'
        }
        app_table.put_item(Item=item)
        return response(201, item)

    # --- 3. ROUTES POLLS (GET /polls ou GET /polls/{id}) ---
    if path.startswith('/polls'):
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
            body = json.loads(event.get('body', '{}'))
            name = body.get('name')
            if not name: return response(400, {'error': 'Name required'})
            
            item = {'id': str(uuid.uuid4()), 'name': name}
            polls_table.put_item(Item=item)
            return response(201, item)

    # Si aucune route ne correspond
    return response(405, {'error': f'Method {method} not allowed on {path}'})