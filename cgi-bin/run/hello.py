#!/usr/bin/python

from mako.template import Template
from mako import exceptions

from cgicommon import *

stt = state()
stt.do_headers()

try:
	header = Template(filename='../templates/header.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
	footer = Template(filename='../templates/footer.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
	body = Template(filename='../templates/hello.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')

	print header.render(get_val('name'))
	print '<div id="headers" class="fieldWithErrors">%s</div>'%stt.format_headers()
	if len(stt.messages) > 0:
		print '<br /><div id="alertDiv">'
		for message in stt.messages:
			print message + '<br />\n'
		print '</div>'
	print body.render('Amir',3)
	print footer.render()

except:
	print exceptions.html_error_template().render()
