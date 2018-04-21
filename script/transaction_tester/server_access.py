import xml.etree.ElementTree as ET
import sys,urllib
import MultipartPostHandler, urllib2 # for file uploads

url_opener = urllib2.build_opener(MultipartPostHandler.MultipartPostHandler)

url = "http://amir-laptop-ubu6000:8010"
#url = 'http://www.icanlocalize.local'
#url = 'http://sandbox.icanlocalize.com'

def call(controller, action, params, post=False):
                    
    if action != '':
        furl = "%s/%s/%s.xml"%(url,controller,action)
    else:
        furl = "%s/%s.xml"%(url,controller)

    if post:

        sys.lastquery = "POST: %s | %s"%(furl,params)
        c = url_opener.open(furl,params)
    else:
        args = urllib.urlencode(params)

        sys.lastquery = "GET: %s?%s"%(furl,args)
        c = url_opener.open("%s?%s"%(furl,args))

    res = ET.parse(c)
    c.close()
                
    return res

