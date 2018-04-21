#from sitespider import *

import string, cgi
from Cookie import SimpleCookie

form = cgi.FieldStorage()

def gel_all_vals():
    res = {}
    for key in form.keys():
        res[key] = form.getfirst(key)
    return res

def get_val(field, default=None):
    if form.has_key(field):
        v = form.getfirst(field)
        return v
    else:
        return default

def get_raw(field):
    if form.has_key(field):
        return form[field]
    else:
        return None

def get_list(field):
	return form.getlist(field)

def has_val(field):
    return form.has_key(field)

class state:

    def __init__(self):
        self.current_site = None
        self.headers = {}
        self.messages = []

        try:
            sid = int(SimpleCookie(os.environ['HTTP_COOKIE'])['sid'].value)
            add_message('Got SID: %d'%sid)
        except:
            sid = None
            self.add_message('No SID cookie')
        #if sid:
        #    self.current_site = session.query(Site).get(sid)
        
    def format_headers(self):
        res = ''
        for k, v in self.headers.items():
            res += '%s: %s\n' % (k, v)
        res += '\n'
        return res

    def add_message(self, msg):
        self.messages.append(msg)

    def do_headers(self):
        self.headers['Content-type'] = 'text/html'
        if self.current_site:
            self.headers['Set-Cookie'] = 'sid=%s;' % self.current_site.id
        print self.format_headers()

    
