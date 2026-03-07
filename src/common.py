import json
import boto3
import os
import time
import requests
from jose import jwk, jwt
from jose.utils import base64url_decode

# DynamoDB resource
dynamodb = boto3.resource('dynamodb')

# JWKS cache
_JWKS_CACHE = {}


def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body)
    }


def get_jwks(region, pool_id):
    key = f"{region}:{pool_id}"
    if key in _JWKS_CACHE and _JWKS_CACHE[key]['exp'] > time.time():
        return _JWKS_CACHE[key]['jwks']
    url = f"https://cognito-idp.{region}.amazonaws.com/{pool_id}/.well-known/jwks.json"
    r = requests.get(url, timeout=5)
    r.raise_for_status()
    jwks = r.json()
    _JWKS_CACHE[key] = { 'jwks': jwks, 'exp': time.time() + 3600 }
    return jwks


def validate_token(token, region, pool_id):
    if not token:
        return False, {'error': 'missing token'}
    try:
        headers = jwt.get_unverified_header(token)
        kid = headers.get('kid')
        jwks = get_jwks(region, pool_id)
        key = None
        for k in jwks.get('keys', []):
            if k.get('kid') == kid:
                key = k
                break
        if not key:
            return False, {'error': 'kid not found in jwks'}

        public_key = jwk.construct(key)
        message, encoded_sig = token.rsplit('.', 1)
        decoded_sig = base64url_decode(encoded_sig.encode('utf-8'))
        if not public_key.verify(message.encode('utf-8'), decoded_sig):
            return False, {'error': 'signature verification failed'}

        claims = jwt.get_unverified_claims(token)
        if claims.get('exp', 0) < time.time():
            return False, {'error': 'token expired'}
        iss = f"https://cognito-idp.{region}.amazonaws.com/{pool_id}"
        if claims.get('iss') != iss:
            return False, {'error': 'invalid issuer'}

        return True, claims
    except Exception as e:
        return False, {'error': str(e)}


def extract_token_from_event(ev):
    headers = ev.get('headers') or {}
    auth = headers.get('authorization') or headers.get('Authorization') or ''
    if auth.startswith('Bearer '):
        return auth.split(' ', 1)[1]
    return auth
