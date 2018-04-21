#!/usr/bin/python

from catch_error import *

from mako.template import Template
from mako import exceptions

from cgicommon import *

import os, string

debug = False
COST_PER_WORD = 7 # USD cents


# ------------- main code --------------

stt = state()
stt.do_headers()

#for k,v in gel_all_vals().items():
#	stt.add_message("field '%s': %s"%(k,v))

errors = []
warnings = []

wc = 0
cost = 0

if has_val('text'):
	text_to_translate = get_val("text")
	wc = len(string.split(text_to_translate))
	cost = wc*COST_PER_WORD

if wc == 0:
	errors.append('No text entered')

if len(errors) == 0:
	title = 'Quote for Your Text Translation'
else:
	title = 'There was a problem with your upload'

header = Template(filename='../templates/header_instant_text.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
print header.render(title)

if debug:
	print "<br /><div><h4>Arguments</h4><ul>"
	for k,v in gel_all_vals().items():
		print "<li>%s: %s</li>"%(k,v)
	print "</ul></div>"
	if len(stt.messages) > 0:
		print '<br /><div id="alertDiv">'
		for message in stt.messages:
			print message + '<br />\n'
		print '</div>'

# display either the normal body or a list of errors
if len(errors) == 0:
	body = Template(filename='../templates/check_text.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
	print body.render(wc, cost)
else:
	body = Template(filename='../templates/errors.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
	print body.render(errors)


footer = Template(filename='../templates/footer.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
print footer.render()

