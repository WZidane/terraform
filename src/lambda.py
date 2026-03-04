import json
import boto3
import os

# Initialisation du client DynamoDB
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    # On récupère le nom de la table via les variables d'environnement (plus propre)
    table_name = os.environ.get('CANDIDATS_TABLE', 'Candidats')
    table = dynamodb.Table(table_name)
    
    try:
        # Récupération de tous les candidats
        response = table.scan()
        items = response.get('Items', [])
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Autorise ton site S3 à lire les données
            },
            'body': json.dumps(items)
        }
    except Exception as e:
        print(f"Erreur : {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({"error": "Impossible de récupérer les candidats"})
        }