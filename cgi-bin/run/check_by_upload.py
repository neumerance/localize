#!/usr/bin/python

from catch_error import *

from mako.template import Template
from mako import exceptions

from cgicommon import *

import zipfile, os, string, md5, urlparse, httplib, time
import TA_html_extractor

import lang_db

debug = False
MAX_AUTO_LINKS = 60
TEMPORARY_UNIFORM_COST = 9

process_extensions = ['htm','html', 'asp', 'aspx', 'php', 'shtml']

def get_extension(fname):
	extpos = string.rfind(fname,'.')
	if extpos > 0:
		return string.lower(fname[extpos+1:])
	else:
		return ''
	

def process_html_file(filename, cont, sentences, file_stats, unique_stats, scanned_links):
	extractor = TA_html_extractor.TA_html_extractor("english")
	try:
		text_buffer = extractor.extract(filename, cont)
	except:
		return []

	for i in range(text_buffer.get_paragraph_count()):
		paragraph = text_buffer.get_paragraph(i)

		if paragraph.has_text():
			paragraph_text = paragraph.get_text(text_buffer.get_original_language())

			words = len(string.split(paragraph_text))

			# count all texts
			if not file_stats.has_key(filename):
				file_stats[filename] = [0,0]

			file_stats[filename][0] += 1
			file_stats[filename][1] += words

			# count only new texts
			if not (paragraph_text in sentences):
				sentences.append(paragraph_text)
				if not unique_stats.has_key(filename):
					unique_stats[filename] = [0,0]

				unique_stats[filename][0] += 1
				unique_stats[filename][1] += words

	scanned_links.append(filename)
	return extractor.get_found_links()

def validate_url(url):
	try:
		parts = urlparse.urlparse(url)
		conn = httplib.HTTPConnection(parts[1])
		#if len(parts[4]) > 0:
		#	getpath = "%s?%s"%(parts[2],parts[4])
		#else:
		getpath = parts[2]
		conn.request("GET", getpath)
		response = conn.getresponse()
		status = response.status
		stt.add_message("For page '%s' Got code: %s"%(url,status))
		ok = (status == 200)
		if ok:
			txt = response.read()
		else:
			txt = None
		conn.close()
		return (status == 200), txt, getpath
	except:
		return False, None, None


# ------------- main code --------------

stt = state()
stt.do_headers()

#for k,v in gel_all_vals().items():
#	stt.add_message("field '%s': %s"%(k,v))

errors = []
warnings = []

doc_sign = {}
sentences = []
file_stats = {} # [sentence_count, word_count]
scanned_links = []
unique_stats = {} # [sentence_count, word_count]

# find the languages
lang_session = lang_db.get_session()
lang_query = lang_session.query(lang_db.Language)
lang_cost_query = lang_session.query(lang_db.LanguageCost)

try:
	source_lang_id = int(get_val('source_lang_id'))
except:
	source_lang_id = 0
	
from_lang = lang_query.get(source_lang_id)
if from_lang:
	from_lang_name = from_lang.name
else:
	errors.append('You must select the language to translate from')

dest_id_list = get_list('dest_lang_id')
to_languages = {}
found_to_lang_id = None
for id_str in dest_id_list:
	try:
		dest_id = int(id_str)
		found_to_lang_id = dest_id
		if dest_id != source_lang_id:
			dest_lang = lang_query.get(dest_id)
			cost_in_cents = TEMPORARY_UNIFORM_COST # lang_cost_query.filter_by(from_id=source_lang_id, to_id=dest_id).one().cost_in_cents
			to_languages[dest_lang.name] = float(cost_in_cents) / 100.0
	except:
		pass

if len(to_languages.keys()) == 0:
	if (len(dest_id_list) == 1) and (found_to_lang_id != 0):
		errors.append('The language to translate to should be different than the original language')
	else:
		errors.append('You must select languages to translated to')

# if all OK with the language selection, scan the input file
inptype  = get_val("inptype")
stt.add_message('--> inptype: %s'%inptype)
if len(errors):
	pass

elif inptype == "local":

	uploaded_data = get_raw('uploaded_data')
	stt.add_message("---- got: %s"%uploaded_data.filename)

	# get the type of the uploaded file
	uploaded_type = get_extension(uploaded_data.filename)
	if uploaded_type == 'zip':
		try:
			z = zipfile.ZipFile(uploaded_data.file,'r')
		except:
			z = None		

		# test the zipfile for problems
		if z and (z.testzip() == None):
			il = z.infolist()
			for item in il:
				fn = os.path.basename(item.filename)
				stt.add_message("processing <b>%s</b>"%fn)
				ext = get_extension(fn)
				stt.add_message("--> extension: %s"%ext)
				if ext in process_extensions:
					cont = z.read(item.filename)
					stt.add_message("--> contents length: %d"%len(cont))

					# calculate the signature of this file to filter duplicates
					file_sign = md5.new(cont).hexdigest()
					if not doc_sign.has_key(file_sign):
						doc_sign[file_sign] = item.filename
						process_html_file(item.filename, cont, sentences, file_stats, unique_stats, scanned_links)
		else:
			title = 'Problem with uploaded file'
			errors.append("The file you uploaded doesn't seem to be a valid ZIP file")

	elif uploaded_type in process_extensions:
		process_html_file(uploaded_data.filename, uploaded_data.file.read(), sentences, file_stats, unique_stats, scanned_links)

	else:
		errors.append("The file you uploaded doesn't seem to be a valid HTML or ZIP file")

elif inptype == "remote":
	recursive = has_val("recursive")
	url = get_val("url")
	stt.add_message('--> URL: %s'%url)
	
	if (url == None) or (url == ''):
		errors.append('No website address entered')
	elif (not url.startswith('http://')) and (not url.startswith('https://')):
		url = 'http://' + url

	if (url != None) and (url != ''):
		logdir = '../tmp/mylogs'
		if not os.path.exists(logdir):
			os.mkdir(logdir)
		log_fname = os.path.join(logdir,'check_by_upload.log')
		logf = open(log_fname,'a')
		logf.write("%s: \t%s\n"%(time.asctime(),url))
		
		# remember if recursive
		logf.write("\tRecursive: %s\n"%recursive)
		
		# write the languages
		logf.write("\tFrom: %s\n"%from_lang_name)
		for to_lang_name in to_languages.keys():
			logf.write("\t--> To: %s\n"%to_lang_name)
		logf.write('\n\n')
		logf.close()
		stt.add_message("Wrote to: %s"%log_fname)
	
	if (url == None) or (url == ''):
		pass
	elif not validate_url(url)[0]:
		errors.append("cannot open %s"%url)
	else:
		url_parts = urlparse.urlparse(url)
		domain = url_parts[1]
		basedir = os.path.dirname(url_parts[2])
		if basedir == '':
			basedir = '/'
		
		signatures = {}
		all_links = []
		todo_links = [url]
		while (len(todo_links) > 0) and (len(scanned_links) < MAX_AUTO_LINKS):
			url = todo_links[0]
			todo_links = todo_links[1:]

			stt.add_message("... Checking '%s'"%url)
			ok, txt, getpath = validate_url(url)

			if txt:
				stt.add_message("For '%s' got: %s and %d chars"%(getpath, ok, len(txt)))
				signature = md5.new(txt).hexdigest()
				all_links.append(url)
				if not signatures.has_key(signature):
					# indicate that we just parsed a file with this signature
					signatures[signature] = url

					# calculate the full path for the found link
					path = urlparse.urlparse(url)[2]
					if path == '':
						filename = 'home page'
					else:
						filename = path
					new_links = process_html_file(filename, txt, sentences, file_stats, unique_stats, scanned_links)
					stt.add_message("-> Scanned %s"%filename)

					for link in new_links:
						new_path = urlparse.urljoin(url, link)
						# make sure it's a supported type
						ext = get_extension(new_path)
						if (ext in process_extensions) or (ext == ''):
							# make sure we remain in the same domain
							newpath_parts = urlparse.urlparse(new_path)
							if (newpath_parts[1] == domain) and ((recursive and (newpath_parts[2].startswith(basedir))) or (not recursive and (os.path.dirname(newpath_parts[2]) == basedir))):
								# add this if we havn't yet scanned and it's not in our list yet
								if (scanned_links.count(new_path) == 0) and (todo_links.count(new_path) == 0) and (all_links.count(new_path) == 0):
									todo_links.append(new_path)
									stt.add_message("adding link to: %s"%new_path)
			#else:
			#	warnings.append("Could not process %s"%url)
			
		if (len(scanned_links) >= MAX_AUTO_LINKS) and (len(todo_links) > 0):
			warnings.append("Scan stopped after %d pages. For a complete scan, you need to sign-up."%MAX_AUTO_LINKS)
	
if len(errors) == 0:
	if len(file_stats.keys()) > 0:
		title = 'Cost Estimate for Your Website Translation'
		sentence_count = 0
		word_count = 0
		for k,v in file_stats.items():
			sentence_count += v[0]
			word_count += v[1]

		unique_sentences = 0
		unique_words = 0
		for k,v in unique_stats.items():
			unique_sentences += v[0]
			unique_words += v[1]
	else:
		errors.append('No text could be extracted from the document you uploaded')

if len(errors) != 0:
	title = 'There was a problem with your upload'

header = Template(filename='../templates/header.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
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
	body = Template(filename='../templates/check_by_upload.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
	print body.render(file_stats, sentence_count, word_count, unique_stats, unique_sentences, unique_words, from_lang_name, to_languages, scanned_links, warnings)
else:
	body = Template(filename='../templates/errors.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
	print body.render(errors)


footer = Template(filename='../templates/footer.html', output_encoding='utf-8', module_directory='../tmp/mako_modules')
print footer.render()

