#!/usr/bin/env python3
"""Push a signed App Bundle to a Google Play track.

iOS has uploaded itself to TestFlight since build 21, because the workflow
holds an App Store Connect API key. Android held only signing secrets, so
every Android build ended the same way: a human, a file picker, and a 66 MB
file carried by hand. Build 27 is the one that made the cost obvious.

This talks to the Play Developer API directly rather than through a
third-party action, so the service-account key stays on the runner and no
borrowed code ever sees it.
"""
import json
import os
import pathlib
import sys

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'
UPLOAD = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3'
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'

# Play truncates anything longer, silently, in the store listing.
NOTE_LIMIT = 500


def authorized_session():
    key = os.environ['PLAY_SERVICE_ACCOUNT_JSON']
    credentials = service_account.Credentials.from_service_account_info(
        json.loads(key), scopes=[SCOPE])
    credentials.refresh(google.auth.transport.requests.Request())
    session = requests.Session()
    session.headers['Authorization'] = 'Bearer %s' % credentials.token
    return session


def checked(response):
    """Fail loudly with Play's own words.

    The API answers a bad edit with a 400 whose body names the field; a bare
    raise_for_status would throw that away and leave a log that says only
    'Bad Request'.
    """
    if not response.ok:
        sys.exit('%s %s -> %s: %s' % (response.request.method,
                                      response.request.url,
                                      response.status_code,
                                      response.text.strip()))
    return response.json() if response.content else {}


def release_notes(directory):
    """One entry per `<language>.txt`, e.g. de-DE.txt.

    Checked here rather than at the store, because a note that is too long
    is accepted and then cut, and nobody reads their own listing closely
    enough to notice where.
    """
    notes = []
    for path in sorted(pathlib.Path(directory).glob('*.txt')):
        text = path.read_text(encoding='utf-8').strip()
        if len(text) > NOTE_LIMIT:
            sys.exit('%s is %d characters; Play allows %d.'
                     % (path, len(text), NOTE_LIMIT))
        notes.append({'language': path.stem, 'text': text})
    if not notes:
        sys.exit('No release notes found in %s.' % directory)
    return notes


def verified_track(session, edits, edit_id, track):
    """Refuse an unknown track, and say which ones exist.

    A custom closed track carries an id of its own, which the Play Console
    does not show anywhere in its interface. Pushing to a track that is not
    there would otherwise either create one nobody is enrolled in or fail
    with a message that names nothing useful.
    """
    tracks = checked(session.get('%s/%s/tracks' % (edits, edit_id),
                                 timeout=60)).get('tracks', [])
    names = [entry['track'] for entry in tracks]
    if track not in names:
        sys.exit('No track named %r. This app has: %s.'
                 % (track, ', '.join(names) or 'none'))
    return track


def main():
    package = os.environ['PLAY_PACKAGE']
    track = os.environ['PLAY_TRACK']
    bundle_path = pathlib.Path(os.environ['PLAY_AAB'])
    notes = release_notes(os.environ['PLAY_NOTES_DIR'])

    if not bundle_path.is_file():
        sys.exit('No App Bundle at %s.' % bundle_path)

    session = authorized_session()
    edits = '%s/applications/%s/edits' % (API, package)

    edit_id = checked(session.post(edits, timeout=60))['id']

    # Checked before the upload, not after: a wrong track id should cost a
    # request, not 66 MB and ten minutes.
    verified_track(session, edits, edit_id, track)

    with bundle_path.open('rb') as bundle:
        uploaded = checked(session.post(
            '%s/applications/%s/edits/%s/bundles' % (UPLOAD, package, edit_id),
            params={'uploadType': 'media'},
            headers={'Content-Type': 'application/octet-stream'},
            data=bundle,
            timeout=900))

    version_code = uploaded['versionCode']
    print('Uploaded version code %s from %s' % (version_code, bundle_path))

    checked(session.put(
        '%s/%s/tracks/%s' % (edits, edit_id, track),
        json={
            'track': track,
            'releases': [{
                'versionCodes': [str(version_code)],
                'status': 'completed',
                'releaseNotes': notes,
            }],
        },
        timeout=60))

    checked(session.post('%s/%s:commit' % (edits, edit_id), timeout=120))
    print('Committed to the %s track: %s in %s languages.'
          % (track, version_code, len(notes)))


if __name__ == '__main__':
    main()
