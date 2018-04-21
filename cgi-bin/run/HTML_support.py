# HTML_support.py

import HTMLParser
from urllib import urlopen
import urlparse
import os
import md5

def fix_HTMLParser_problem():
    #fix the HTMLParser to handle attributes that are missing a space
    # eg.  <img src="/assets/img_top1.jpg" alt="image"  title="image"width="131" height="112">
    #See: http://mail.python.org/pipermail/python-bugs-list/2004-December/026844.html
    import re
    HTMLParser.locatestarttagend = re.compile(r"""
      <[a-zA-Z][-.a-zA-Z0-9:_]*          # tag name
      \s*                                # whitespace after tag name
      (?:
        (?:[a-zA-Z_][-.:a-zA-Z0-9_]*     # attribute name
          (?:\s*=\s*                     # value indicator
            (?:'[^']*'                   # LITA-enclosed value
              |\"[^\"]*\"                # LIT-enclosed value
              |[^'\">\s]+                # bare value
             )?
           )?
         )
         \s*                             # whitespace between attrs
       )*
      \s*                                # trailing whitespace
    """, re.VERBOSE)

fix_HTMLParser_problem()

class HTML_title_finder(HTMLParser.HTMLParser):

    # DATA ####################################################################
    
    __in_title_tag = False
    
    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, remote = False):
        HTMLParser.HTMLParser.__init__(self)

        self.__in_title_tag = False
        
        self.__current_title = u""
        self.__encoding = ""
        
        self.__title_found = False
        
        self.__remote = remote
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def handle_starttag(self, tag, attrs):

        tag = tag.lower()

        if tag == "title":
            self.__in_title_tag = True

        if tag == "meta":            
            for attr in attrs:
                if attr[0] == "content" and attr[1].startswith("text/html; charset="):
                
                    # record the encoding
                
                    self.__encoding = attr[1][len("text/html; charset="):]
            
        #----------------------------------------------------------------------
    def handle_endtag(self, tag):
        
        self.__in_title_tag = False
        
        tag = tag.lower()

        if tag == 'title':
            self.__title_found = True

        #----------------------------------------------------------------------
    def handle_data(self, data):
        
        if self.__in_title_tag:
            if self.__encoding != "":
                self.__current_title = unicode(data, self.__encoding)
            else:
                self.__current_title = unicode(data, "ISO-8859-1")
                
    
        #----------------------------------------------------------------------
    def get_title_and_md5(self, file_name):

        self.__in_title_tag = False
        
        self.__current_title = u""
        self.__encoding = ""
        self.__current_md5 = ""
        
        self.__title_found = False

        try:
            if self.__remote:
                data = urlopen(file_name).read()
            else:
                data = open(file_name, 'r').read()

            self.__current_md5 = md5.new(data).hexdigest()
            
            data = data.split("\n")
            
            self.reset()
            
            for line in data:
                self.feed(line)
                
                if self.__title_found:
                    return self.__current_title, self.__current_md5
                    
        except:
            pass
            
        return self.__current_title, self.__current_md5
                
        
    #----------------------------------------------------------------------

def get_title(html_file_name):
    
    finder = HTML_title_finder()
    
    return finder.get_title(html_file_name)
    

###############################################################################

               
        
#####################################################################

if __name__ == "__main__":
    
    print get_title("sample_website\\index.htm")
    