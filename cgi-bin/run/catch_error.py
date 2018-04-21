import os,sys,traceback,string,cgi

def Myexcepthook(type, value, tb):
    sys.stderr = open("logs/error_handler_log.txt","a")
    lines=traceback.format_exception(type, value, tb)
    report = ""
    report = report + "---------------------Traceback lines-----------------------\n"
    report = report + "\n".join(lines)+"\n"
    report = report + "-----------------------------------------------------------\n"
    if sys.more_info != "":
        report = report + "additional information:\n%s\n"%sys.more_info

    # get the call data
    if os.environ.has_key('REQUEST_METHOD'):
        method = os.environ['REQUEST_METHOD'].upper()
    else:
        method = ''

    file_called = sys.argv[0]
    report = report + '\nFull URL:\n%s %s\n'%(method, file_called)
    report = report + '\nArguments:\n'
    
    form = cgi.FieldStorage()
    for key in form.keys():
        report = report + '%s: %s\n'%(key,', '.join(form.getlist(key)))

    report += '\n-------------- end argument list --------------'

    # send the report home
    #f = os.popen("/usr/sbin/sendmail support@onthegosoft.com",'w')
    #f.write("to: support@onthegosoft.com\n")
    #f.write("from: support@onthegosoft.com\n")
    #f.write("subject: SCRIPT ERROR!\n\n")
    #f.write(report)
    #f.close()
    txt = ('<h1>Server Error</h1>An unhandled error occurred. Please contact '+
           '<a href="mailto:support@onthegosoft.com">support@onthegosoft.com</a> with the link to the page '+
           'that caused the problem, and a brief description of what you were doing.<br>'+
           '<br>Thank you,<br>OnTheGoSoft<br>')
    if True:
        txt = report

	#print "Content-type: text/html\n\n"
	print "<html>%s</html>"%string.replace(txt,'\n','<br>\n')
    sys.stderr.close()
    sys.exit(0)

# attach the system exception handler
sys.more_info = ""
sys.excepthook = Myexcepthook
