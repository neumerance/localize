from mako.template import Template
from mako import exceptions

from cgicommon import *

import zipfile, os, string, md5
#import TA_html_extractor

import lang_db

lang_session = lang_db.get_session()
lang_query = lang_session.query(lang_db.Language)

print lang_query.get(1).name
