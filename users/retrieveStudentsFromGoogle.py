#!/usr/bin/env python

import httplib2
import os
import pprint
import sys
from apiclient.discovery import build
from oauth2client import client
from oauth2client import tools
from oauth2client.file import Storage

try:
    import argparse
    flags = argparse.ArgumentParser(parents=[tools.argparser]).parse_args()
except ImportError:
    flags = None

SCOPES = ['https://www.googleapis.com/auth/admin.directory.user.readonly']
CLIENT_SECRET_FILE = 'client_secret.json'
APPLICATION_NAME = 'StudentEmailRetrieverScript'

def get_credentials():
    """Gets valid user credentials from storage.

    If nothing has been stored, or if the stored credentials are invalid,
    the OAuth2 flow is completed to obtain the new credentials.

    Returns:
        Credentials, the obtained credential.
    """
    home_dir = os.path.expanduser('~')
    credential_dir = os.path.join(home_dir, '.credentials')
    if not os.path.exists(credential_dir):
        os.makedirs(credential_dir)
    credential_path = os.path.join(credential_dir, 'gmail-python-quickstart.json')

    store = Storage(credential_path)
    credentials = store.get()
    if not credentials or credentials.invalid:
        flow = client.flow_from_clientsecrets(CLIENT_SECRET_FILE, SCOPES)
        flow.user_agent = APPLICATION_NAME
        if flags:
            credentials = tools.run_flow(flow, store, flags)
        else: # Needed only for compatibility with Python 2.6
            credentials = tools.run(flow, store)
        print('Storing credentials to ' + credential_path)
    return credentials

credentials = get_credentials()
http = credentials.authorize(httplib2.Http())
service = build('admin', 'directory_v1', credentials=credentials)
users = service.users().list(domain="lfkyoto.org", orderBy="familyName").execute()
students = [user for user in users.get('users') if user.get('orgUnitPath') == '/Eleves' and not user.get('suspended')]
for student in students:
    print "Name: {0}  Email: {1}  Last login: {2}".format(student.get('name').get('fullName').encode('utf-8'), student.get('emails')[0].get('address'), student.get('lastLoginTime'))

