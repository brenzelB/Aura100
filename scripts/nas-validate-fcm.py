"""Run with python3 on NAS-BRA. Validates FCM without sending notifications.

Secrets and registration tokens stay on the NAS and are never printed.
"""
import base64
import json
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


def command(args):
    return subprocess.check_output(args, stderr=subprocess.DEVNULL).decode().strip()


def post(url, body, headers):
    request = urllib.request.Request(url, data=body, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def encoded(value):
    raw = json.dumps(value, separators=(',', ':')).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b'=').decode()


def main():
    env = dict(value.split('=', 1) for value in json.loads(command([
        'docker', 'inspect', 'auraquest-functions', '--format', '{{json .Config.Env}}'])))
    account = json.loads(base64.b64decode(env['FCM_SERVICE_ACCOUNT_B64']))
    now = int(time.time())
    unsigned = encoded({'alg': 'RS256', 'typ': 'JWT'}) + '.' + encoded({
        'iss': account['client_email'], 'scope': 'https://www.googleapis.com/auth/firebase.messaging',
        'aud': 'https://oauth2.googleapis.com/token', 'iat': now, 'exp': now + 3600})
    with tempfile.TemporaryFile() as key:
        key.write(account['private_key'].encode())
        key.flush()
        signature = subprocess.check_output(['openssl', 'dgst', '-sha256', '-sign',
            '/proc/self/fd/' + str(key.fileno())], input=unsigned.encode(),
            pass_fds=(key.fileno(),), stderr=subprocess.DEVNULL)
    jwt = unsigned + '.' + base64.urlsafe_b64encode(signature).rstrip(b'=').decode()
    status, auth = post('https://oauth2.googleapis.com/token', urllib.parse.urlencode({
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion': jwt}).encode(),
        {'Content-Type': 'application/x-www-form-urlencoded'})
    if status != 200:
        raise RuntimeError('OAuth authentication failed (HTTP ' + str(status) + ')')
    rows = json.loads(command(['docker', 'exec', 'auraquest-db', 'psql', '-XAt', '-U',
        'postgres', '-d', 'postgres', '-c', "select coalesce(json_agg(t),'[]') from "
        "(select id,token from public.device_tokens where provider='fcm') t;"]))
    results = []
    for row in rows:
        status, response = post('https://fcm.googleapis.com/v1/projects/' + account['project_id'] + '/messages:send',
            json.dumps({'validate_only': True, 'message': {'token': row['token'],
                'data': {'category': 'quest', 'id': '0', 'refId': ''},
                'android': {'priority': 'high'},
                'apns': {'headers': {'apns-priority': '5', 'apns-push-type': 'background'},
                    'payload': {'aps': {'content-available': 1}}}}}).encode(),
            {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + auth['access_token']})
        results.append({'device_id': row['id'], 'http_status': status,
            'error_status': response.get('error', {}).get('status'),
            'fcm_error': [d.get('errorCode') for d in response.get('error', {}).get('details', [])
                if d.get('@type') == 'type.googleapis.com/google.firebase.fcm.v1.FcmError']})
    print(json.dumps({'validation_only': True, 'devices': results}))
    if any(r['http_status'] != 200 for r in results):
        raise RuntimeError('FCM validation failed for one or more devices')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Do not print raw HTTP responses, environment, or credentials.
        print('FCM validation error: ' + type(error).__name__)
        raise SystemExit(1)
