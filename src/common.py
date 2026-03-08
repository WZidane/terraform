import json
import boto3

# Ressource DynamoDB partagée pour éviter les répétitions
dynamodb = boto3.resource('dynamodb')

def response(status_code, body):
    """Génère une réponse HTTP formatée pour API Gateway"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body)
    }