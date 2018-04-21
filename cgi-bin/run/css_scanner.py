import re
import os
from urlparse import urlparse, urljoin
from urllib import urlopen

import TA_html_support_files

class CSS_scanner:

    # DATA ####################################################################
    
    __found_files = []
    __processed_files = []
    
    __base_directory = ""
    
    __remote = False
    __file_cache = None
    
    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, remote = False, file_cache = None):

        self.__found_files = []
        self.__processed_files = []
        
        self.__base_directory = ""
        
        self.__remote = remote
        
        self.__file_cache = file_cache
        
        
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def process(self, file_name, feed_back = None):
        
        if feed_back and feed_back.is_cancelled():
            return
        
        if not self.__remote:
            file_name = os.path.normpath(file_name)
    
        if file_name not in self.__processed_files:
            
            
            self.__current_file = file_name

            data = ""            
            try:

                # open file file

                if self.__remote:
                    cached_file_name = None
                    if self.__file_cache:
                        cached_file_name = self.__file_cache.get_cache_file(file_name)
                        
                    if cached_file_name != None:
                        data = open(cached_file_name, 'r').read()
                    else:
                        data = urlopen(file_name).read()
                        if self.__file_cache:
                            self.__file_cache.save_cache_file(file_name, data)

                    self.__base_directory = file_name
                else:
                    data = open(file_name, 'r').read()
                    self.__base_directory = os.path.split(file_name)[0]

                parts = urlparse(file_name)
                
            except:
                pass
            
            self.__processed_files.append(file_name)

            self.scan(data, '[\t ]*background-image[\t ]*:[\t ]*url\("?(.*?)"?\).*', feed_back)
            self.scan(data, '[\t ]*background[\t ]*:[\t ]*url\("?(.*?)"?\).*', feed_back)
            self.scan(data, '[\t ]*list-style-image[\t ]*:[\t ]*url\("?(.*?)"?\).*', feed_back)
            
        #----------------------------------------------------------------------
    def scan(self, data, pattern_to_match, feed_back):            
            pattern = re.compile(pattern_to_match)
            for line in data.split("\n"):
                
                match = pattern.match(line)
                
                if match:
                    file = match.group(1)
                    
                    #if self.__remote:
                    #    file = urljoin(self.__base_directory, file)
                    #else:
                    #    file = os.path.join(self.__base_directory, file)
                    #    file = os.path.normpath(file)

                    if not self.__remote:
                        file = os.path.normpath(file)
                    
                    if file not in self.__found_files:
                        self.__found_files.append(file)
                        if feed_back:
                            feed_back.new_file(file)

        
        #----------------------------------------------------------------------
    def get_files(self):
        
        return self.__found_files

#####################################################################
        
def are_selected_in_file(project, support_file_directory, file, states):
    
    file_data = TA_html_support_files.get_support_file_data(project, support_file_directory, file)
    
    if file_data != None:
        for key in states.keys():
            if states[key]:
                # support file is being duplicated
                # check to see if it is in the style sheet.
                if file_data.find(key) >= 0:
                    return True
                
    return False

        
if __name__ == "__main__":
    
    finder = CSS_scanner()
    
    class printer_temp:
        
        def new_file(self, file_name):
            print file_name
            
        def is_cancelled(self):
            return False
            
    feed_back = printer_temp()
    

    finder = CSS_scanner(remote = False)
    finder.process('sample_website/styles.css', feed_back)
    
    finder = CSS_scanner(remote = True)
    finder.process('http://www.onthegosoft.com/styles.css', feed_back)
    
    print finder.get_files()

    
    
        
        
            
