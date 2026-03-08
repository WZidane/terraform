import os
import json
import uuid
import boto3
from common import response, dynamodb

polls_table = dynamodb.Table(os.environ.get('POLLS_TABLE'))
applications_table = dynamodb.Table(os.environ.get("APPLICATIONS_TABLE"))
s3_client = boto3.client("s3")


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

    print(f"user_id: {user_id}")

    # -----------------------------
    # GET /get-presigned-url
    # -----------------------------
    if method == "GET" and "get-presigned-url" in path:

        if not user_id:
            return response(401, {'error': 'Utilisateur non authentifié'})

        file_name = event.get("queryStringParameters", {}).get("filename", str(uuid.uuid4()))

        try:
            url = s3_client.generate_presigned_url(
                "put_object",
                Params={
                    "Bucket": os.environ["BUCKET_NAME"],
                    "Key": f"candidatures/{file_name}"
                },
                ExpiresIn=300
            )

            return response(200, {"upload_url": url})

        except Exception as e:
            return response(500, {"error": str(e)})
        

    if method == "GET" and "applications" in path and "polls" in path:

        poll_id = path_params.get("id")

        if not poll_id or not user_id:
            return response(400, {"error": "poll_id et user_id requis"})
            
        resp = polls_table.get_item(Key={'id': poll_id})
        existing_poll = resp.get('Item')

        if not existing_poll:
            return response(404, {'error': "Sondage introuvable"})

        if not existing_poll.get('is_active'):
            return response(400, {'error': "Cette élection est déjà clôturée"})

        rep = applications_table.get_item(
            Key={
                "poll_id": poll_id,
                "user_id": user_id
            }
        )

        return response(200, rep.get('Item'))

    # GET /get-download-url?document_id=xxx
    if method == "GET" and "get-download-url" in path:
        doc_id = event.get("queryStringParameters", {}).get("document_id")
        
        if not doc_id:
            return response(400, {"error": "document_id requis"})

        try:
            # Génère une URL de lecture valable 10 minutes
            url = s3_client.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": os.environ["BUCKET_NAME"],
                    "Key": f"candidatures/{doc_id}"
                },
                ExpiresIn=600 
            )
            return response(200, {"download_url": url})
        except Exception as e:
            return response(500, {"error": str(e)})

    if method == "GET" and "applications" in path:
        
        poll_id = path_params.get("id")

        if not poll_id:
            return response(400, {"error": "poll_id requis"})

        resp = applications_table.scan(
            FilterExpression="poll_id = :poll_id",
            ExpressionAttributeValues={":poll_id": poll_id}
        )

        items = resp.get("Items", [])

        for item in items:
            if 'votes' in item:
                item['votes'] = int(item['votes'])
        
        print(f"Applications pour le poll {poll_id} : {items}")

        return response(200, items)

    # -----------------------------
    # POST /applications/{id}/
    # -----------------------------
    if method == "POST":

        poll_id = path_params.get("id")

        if not poll_id or not user_id:
            return response(400, {"error": "poll_id et user_id requis"})
        
        resp = polls_table.get_item(Key={'id': poll_id})
        existing_poll = resp.get('Item')

        if not existing_poll:
            return response(404, {'error': "Sondage introuvable"})

        if not existing_poll.get('is_active'):
            return response(400, {'error': "Cette élection est déjà clôturée"})
        
        rep = applications_table.get_item(
            Key={
                "poll_id": poll_id,
                "user_id": user_id
            }
        )

        if rep.get('Item') is not None:
            return response(400, {'error': "Vous êtes déjà inscrit pour cette élection."})

        body = json.loads(event.get("body", "{}"))

        application_id = str(uuid.uuid4())

        given_name = claims.get('given_name') or claims.get('custom:given_name', '')
        family_name = claims.get('family_name') or claims.get('custom:family_name', '')
        creator_name = f"{given_name} {family_name}".strip()

        item = {
            "id": application_id,
            "poll_id": poll_id,
            "user_id": user_id,
            "candidate_name": creator_name or "Anonyme",
            "document_id": body.get("document_id", None),
        }

        applications_table.put_item(Item=item)

        return response(201, item)

    return response(405, {"error": f"Method {method} not allowed"})