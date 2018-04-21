# TA_html_extractor.py

import os
import os.path
import md5
from xml.etree.cElementTree import Element, SubElement

import HTMLParser
import HTML_support
HTML_support.fix_HTMLParser_problem()


import htmlentitydefs

# add the apostrophe
#htmlentitydefs.name2codepoint['apos'] = 0x0027
#print htmlentitydefs.name2codepoint['apos']

from TA_text_buffer import *


special_tags = ["img", "input"]
special_tags_attributes = {"img" : "alt", "input" : "value"}


tag_colors = {'b' : 'RED',
          'i' : 'GREEN',
          'a' : 'BLUE',
          'u' : 'YELLOW'}

class TA_html_format_marker(TA_text_format_marker):
    """ Stores the information about html tags in a paragraph. """
    
    # DATA ####################################################################
    
    __start = False # indicates if this is a start tag.
    __tag = "" # the tag
    __attrs = None # attributes for a start tag
    __id = 0 # id for a tag. Used to match start and end tags.

    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, start, tag, id, attrs = None):
        TA_text_format_marker.__init__(self)
        
        self.__start = start
        self.__tag = tag
        self.__attrs = attrs
        self.__id = id
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def save(self, root):
        
        if self.__start or self.__id < 0:
            html_marker = SubElement(root, "html_marker", {"tag" : self.__tag})
            
            if self.__attrs:
                for pair in self.__attrs:
                    attr = SubElement(html_marker, "attr", {"name" : pair[0],
                                                            "val" : pair[1]})
        

        #----------------------------------------------------------------------
    def __repr__(self):
        if self.__start:
            return "Start tag id = %i: %s - %s" % (self.__id, self.__tag, str(self.__attrs))
        else:        
            return "End tag id = %i: %s" % (self.__id, self.__tag)

        #----------------------------------------------------------------------
    def __eq__(self, other):
        return self.__start == other.__start and \
                self.__tag == other.__tag and \
                self.__attrs == other.__attrs and \
                self.__id == other.__id
        
        #----------------------------------------------------------------------
    def is_start_marker(self):
        return self.__start

        #----------------------------------------------------------------------
    def get_marker_id(self):
        return self.__id

        #----------------------------------------------------------------------
    def get_type(self):
        return "html"

        #----------------------------------------------------------------------
    def get_color(self):
        try:
            color_name = tag_colors[self.__tag]
        except:
            color_name = 'PURPLE'
            
        return color_name

        #----------------------------------------------------------------------
    def reconstruct(self, language, encoding, reconstructor, selected):
        return reconstructor.process_tag(self.__start, self.__tag, self.__attrs, selected)

        #----------------------------------------------------------------------
    def get_short_description(self):
        if self.__tag == "img":
            return "image alt"
        elif self.__tag == "a":
            return "link <a>"
        elif self.__tag == "b":
            return "bold"
        elif self.__tag == "u":
            return "underline"
        elif self.__tag == "i":
            return "italic"
        return self.__tag
            
        #----------------------------------------------------------------------
    def create_matching_end_marker(self):
        return TA_html_format_marker(False, self.__tag, self.__id)
        
        
class TA_html_marker_loader:
    
    
    def load(self, xml_data):
        html_marker_xml = xml_data.find("html_marker")
        
        # get the attributes if any.
        
        attrs = []
        
        for attr in html_marker_xml.getiterator("attr"):
            attrs.append((attr.get("name"), attr.get("val")))
        
        
        id = int(xml_data.get("id"))
        return TA_html_format_marker(id >= 0,
                                     html_marker_xml.get("tag"),
                                     id,
                                     attrs)
    
class TA_html_text_block(TA_text_block):
    """ stores a block of text that does not require translation.
        eg javascript. """
        
    # DATA ####################################################################


    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, text, original_language, encoding):
        TA_text_block.__init__(self, text, original_language, encoding)
        
        #----------------------------------------------------------------------
    def get(self, language):
        return ""
            
            
class TA_html_entity_ref:
    """ Stores the special html characters. """
    
    # DATA ####################################################################
    
    __data = ""
    
    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, name):
        self.__data = name
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def __repr__(self):
        return "charref : %s" % self.__data
        

        #----------------------------------------------------------------------
    def reconstruct(self, language, encoding, reconstructor, selected):
        return "&%s;" % self.__data
            
    
class TA_paragraph_text_extractor(HTMLParser.HTMLParser):
    """ Extracts the html tags and the text from a givin paragraph """

    # DATA ####################################################################
    
    __paragarph = None
    __original_language = ""
    __encoding = ""
    
    __tag_ids = {} # a dictionary of open id tags, used to match closing tags.
    __current_tag_id = 0
    
    __processing_script_tag = False # required so the javascript is not
                                    # translated.

    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, language, encoding):
        HTMLParser.HTMLParser.__init__(self)
        
        self.__original_language = language
        self.__encoding = encoding
        self.__tag_ids = {}
        self.__current_tag_id = 0
        
        self.__processing_script_tag = False
        
        self.__error_tag_id = -1
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def handle_starttag(self, tag, attrs):

        tag = tag.lower()
        
        self.__paragarph.add_marker(TA_html_format_marker(True, tag,
                                                    self.__current_tag_id,
                                                    attrs))

        try:
            self.__tag_ids[tag].insert(0, self.__current_tag_id)
        except:
            self.__tag_ids[tag] = []
            self.__tag_ids[tag].insert(0, self.__current_tag_id)
            
        if tag == 'script':
            self.__processing_script_tag = True

        # need to handle special tags
        # eg. the img tag to get the alt text.
        
        if tag in special_tags:
            
            for attr in attrs:
                if attr[0] == special_tags_attributes[tag]:
                    #if len(attr[1]) > 0 and not attr[1].isspace():
                    self.__paragarph.add_text(attr[1])
            
            # add an end tag.
            self.handle_endtag(tag, True)
            #self.__paragarph.add_marker(TA_html_format_marker(False, tag, self.__current_tag_id))
        #if tag == "img":
        #    
        #    # we need to close the image tag.
        #    
        #    self.__paragarph.add_marker(TA_html_format_marker(False, tag, self.__current_tag_id))
                        
            
        self.__current_tag_id += 1

        #----------------------------------------------------------------------
    def handle_endtag(self, tag, from_special_tag_start = False):
        
        tag = tag.lower()
        
        if tag in special_tags and not from_special_tag_start:
            # we close our img tags from the handle_starttag function.
            # at this point the parser has called end tag which we
            # can ignore for images
            return
        
        # find the matching tag id.
        
        try:
            tag_id = self.__tag_ids[tag][0]
            del self.__tag_ids[tag][0]
        except:
            # no matching start tag.
            # this can happen eg.  <a ref="xxx">some text<br>more text</a>
            tag_id = self.__error_tag_id
            self.__error_tag_id -= 1
        
        self.__paragarph.add_marker(TA_html_format_marker(False, tag, tag_id))
            
        if tag == 'script':
            self.__processing_script_tag = False

        #----------------------------------------------------------------------
    def handle_data(self, data):
        if self.__processing_script_tag:
            self.__paragarph.add(TA_html_text_block(data, self.__original_language, self.__encoding))
        else:
            # remove the extra white space, etc
            output = ""
            last_char = ""
            
            white_space = [' ', '\t', '\n', '\r']
            for char in data:
                if char in white_space:
                    if last_char != ' ':
                        output += ' '
                        last_char = ' '
                else:
                    output += char
                    last_char = char
                
            
            # Check for title and meta data
            
            if output.startswith(title_marker):
                output = output[len(title_marker):]
                self.__paragarph.set_type_as_title()

            if output.startswith(meta_name_marker):
                end_marker = output.rfind(meta_name_marker)
                name = output[len(meta_name_marker):end_marker]
                self.__paragarph.set_type_as_meta(name)
                output = output[end_marker + len(meta_name_marker):]

            self.__paragarph.add_text(output)
            

        #----------------------------------------------------------------------
    def handle_comment(self, data):
        pass
        #print "comment %s" % data

        #----------------------------------------------------------------------
    def handle_decl(self, decl):
        pass
        #print "decl %s" % decl
        
        #----------------------------------------------------------------------
    def handle_charref(self, name):
        #print "charref %s" % name
        pass
        
        #----------------------------------------------------------------------
    def handle_entityref(self, name):
        try:
            char = unichr(htmlentitydefs.name2codepoint[name])
            self.__paragarph.add_unicode(char)
        except:
            self.__paragarph.add_text("&%s" % name)
        
        #----------------------------------------------------------------------
    def handle_pi(self, data):
        pass
        #print "pi %s" % data
        
        #----------------------------------------------------------------------
    def extract(self, stream, paragarph):

        #print "------" + stream + "------"
        
        self.__paragarph = paragarph
        
        self.feed(stream)


start_marker = "~####"
end_marker = "####~"

class TA_html_text_buffer(TA_text_buffer):

    # DATA ####################################################################

    __marked_file = ""  # This is the original file with the paragraphs marked
                        # with the paragarph markers, usually ~#### and ####~.
                        
    __paragraph_indexes = []    # a list indexes into the marked file
                                # recording start and end positions of
                                # paragraphs.
                                
    __original_language = ""
    __encoding = ""
    __encoding_found = False
    
    
    __support_files = {}
    
    __file_name = ""
                                
    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, language, encoding):
        TA_text_buffer.__init__(self, language)

        self.__marked_file = ""
        self.__paragraph_indexes = []
        self.__original_language = language
        self.__encoding = encoding
        self.__encoding_found = False
        
        self.__support_files = {}
        
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def save(self, root, common_root_len, clear_dirty_state = True):
        """ save the text buffer to an xml file"""

        # create a root item.
        attrs = {"source_file" : self.__file_name[common_root_len:],
                                         "type" : "html",
                                         "original_language" : self.__original_language,
                                         "encoding" : self.__encoding,
                                         "format" : "1"}
            
        this_xml = Element("ta_buffer", attrs)
        
        # save the extractor infomation.
        extractor = SubElement(this_xml, "extractor")
        
        # save the marked up file. zip it and convert to hex
        
        marked_file = SubElement(extractor, "marked_file", {"MD5" : md5.new(self.__marked_file).hexdigest()})
        import binascii
        import zlib
        marked_file.text = binascii.b2a_hex(zlib.compress(self.__marked_file))
        
        # save the paragraph indexes.
        
        paragraph_indexes = SubElement(extractor, "paragraph_indexes", {"count" : "%i" % len(self.__paragraph_indexes)})
        text = ""
        for index in self.__paragraph_indexes:
            text += "%i %i " % (index[0], index[1])

        paragraph_indexes.text = text

        # save the names of the support files.
        
        support_files = SubElement(extractor, "support_files")
        support_file_list = self.__support_files.keys()
        support_file_list.sort()
        for file in support_file_list:
            support_file = SubElement(support_files, "file", {"type" : "todo"})
            support_file.text = file
        
        # now save the common text buffer.
        
        translation = SubElement(this_xml, "translation")
        
        TA_text_buffer.save(self, translation, clear_dirty_state)
        
        # add the created xml data to the root.
        
        root.append(this_xml)
        
        #----------------------------------------------------------------------
    def load(self, xml_data, common_root):
        """ load the text buffer from an xml file"""
        
        self.__file_name = os.path.join(common_root, xml_data.get("source_file"))

        extractor_xml_data = xml_data.find("extractor")
        
        # load marked file.
        
        marked_file = extractor_xml_data.find("marked_file")
        import binascii
        import zlib
        self.__marked_file = zlib.decompress(binascii.a2b_hex(marked_file.text))
        if md5.new(self.__marked_file).hexdigest() != marked_file.get("MD5"):
            raise Exception, "marked file MD5 does not match"
        
        # get the paragraphs indexes.
        
        paragraph_indexes = extractor_xml_data.find("paragraph_indexes")
        text = paragraph_indexes.text
        
        indexes = text.split()
        
        self.__paragraph_indexes = []
        
        for i in range(0, len(indexes), 2):
            # indexes are stored as start and end pairs.
            self.__paragraph_indexes.append((int(indexes[i]), int(indexes[i + 1])))
            
        if len(self.__paragraph_indexes) != int(paragraph_indexes.get("count")):
            raise Exception, "paragraph count is not correct. Should be %i but received %i" % (
                            int(paragraph_indexes.get("count")), len(self.__paragraph_indexes))

        # load the names of the support files.
        
        support_files = extractor_xml_data.find("support_files")
        for file in support_files.getiterator("file"):
            self.__support_files[file.text] = ""
        
        # now load the translation data to the TA_text_buffer
        
        translation = xml_data.find("translation")
        TA_text_buffer.load(self, translation, TA_html_marker_loader())

        #----------------------------------------------------------------------
    def set_file_name(self, file_name):
        self.__file_name = file_name
        
        #----------------------------------------------------------------------
    def get_file_name(self):
        return self.__file_name
        
        #----------------------------------------------------------------------
    def store_marked_file(self, text):
        self.__marked_file = text
        
        #----------------------------------------------------------------------
    def get_marked_file(self):
        return self.__marked_file
        
        #----------------------------------------------------------------------
    def get_support_file_names(self):
        return self.__support_files.keys()
    
        #----------------------------------------------------------------------
    def store_support_file(self, base_directory, file_name):
        
        if base_directory != "":
            file_name = os.path.normpath(os.path.join(base_directory, file_name))
            file_name = file_name.replace("\\", "/")
            
        self.__support_files[file_name] = ""
            
        
        #----------------------------------------------------------------------
    def set_encoding(self, encoding):
        self.__encoding = encoding
        self.__encoding_found = True
        
        #----------------------------------------------------------------------
    def get_encoding(self):
        return self.__encoding
        
        #----------------------------------------------------------------------
    def add_paragraph(self, start_index, end_index, text):
        self.__paragraph_indexes.append((start_index, end_index))
        
        extractor = TA_paragraph_text_extractor(self.__original_language,
                                                    self.__encoding)
        
        paragraph = TA_text_paragraph(self.__original_language,
                                                    self.__encoding)
        
        extractor.extract(text, paragraph)
        
        TA_text_buffer.add_paragraph(self, paragraph)
        
        #----------------------------------------------------------------------
    def can_paragraph_merge_with_next(self, paragraph, next_paragraph):
        
        # if we have a end marker followed by a start marker then we
        # can join them as there is no non sentence stuff in between.
        # eg ####~~####
        
        result_1 = self.__paragraph_indexes[paragraph + 1][0] - self.__paragraph_indexes[paragraph][1] == len(end_marker)

        result_2 = self.__paragraph_indexes[next_paragraph][0] - self.__paragraph_indexes[next_paragraph - 1][1] == len(end_marker)
        
        return result_1 and result_2
        
        #----------------------------------------------------------------------
    def reconstruct_document(self, language, encoding, reconstructor, selected):
        """ reconstructs the document. """

        import wx
        
        output = ""
        
        # we need to output from the marked file but replace the marked
        # paragraphs with the paragraphs from the text buffer.
        
        index = 0
        
        current_position = 0
        
        while index < len(self.__paragraph_indexes):
            
            # output from marked file
            
            data = self.__marked_file[current_position : self.__paragraph_indexes[index][0]]
            if data.find(char_set_marker) >= 0:
                data = data.replace(char_set_marker, encoding)
                self.__encoding_found = True
                
            if not self.__encoding_found:
                # try to enforce the coding.
                
                if data.find("</title>") >= 0:
                    data = data.replace("</title>",
                                        '</title>\n<meta http-equiv="content-type" content="text/html; charset=%s">' % encoding)

            
            output += reconstructor.process_non_paragraph(data)
            
            #print output
                                                         
            
            # output from paragraph.
            
            # TODO: check for special characters like < and > which will need to be converted to &lt; and &gt;
            
            paragraph = self.get_paragraph(index)
            
            text = paragraph.reconstruct(language, encoding, reconstructor,
                                                                  index == selected)

            client_mode = wx.GetApp().is_client_mode()
             
            if paragraph.has_text() and (client_mode or (not client_mode and paragraph.should_be_translated())):
                output += reconstructor.process_paragraph(index,
                                                          text,
                                                          output,
                                                          selectable = (not paragraph.is_title() and not paragraph.is_meta_data()))
            else:
                output += text
            
            current_position = self.__paragraph_indexes[index][1] + len(end_marker)
            
            index += 1
            
        output += self.__marked_file[current_position : ]
        
        return output
            
            
        #----------------------------------------------------------------------
    def reload_new_version_from_source(self, compare_file):
        extractor = TA_html_extractor()
    
        if compare_file == "":
            compare_file = self.__file_name
            
        return extractor.extract(compare_file, open(compare_file, "r").read())
            
        #----------------------------------------------------------------------
    def use_online_support_files(self, output):
        # fix up any paths to images, etc......
        
        import urlparse

        base_file = self.__file_name.replace("\\", "/")
        try:
            base_file = base_file.encode()
        except:
            pass

        source_parts = urlparse.urlparse(base_file)
        if source_parts[0] == "http":
            for file in self.__support_files.keys():
                
                new_file = urlparse.urljoin(base_file, file)
                
                try:
                    output = output.replace(file, new_file)
                except:
                    pass

        return output        
        
        
paragraph_tags = ["br", "hr", "div", "table", "tr", "td", "p", "h1", "h2", "h3", "h4", "h5",
                  "h6", "title", "ul", "li", "form", "span", "script", "dd", "dt", "img", "input"]

sentence_breaks = [". ", ".\t", "?"]

default_encoding = "ISO-8859-1"
#default_encoding = "utf-8"

char_set_marker = "#TA_char_set_marker#"
title_marker = "#TA_TITLE#"
meta_name_marker = "#TA_META_NAME#"
    
class TA_html_extractor(HTMLParser.HTMLParser):

    # DATA ####################################################################
    
    __text_buffer = None
    
    __paragraph_lines = {}
    
    __external_references = []
    
    __file_name = ""
    
    __last_tag = ""
    
    __in_body = False
    __in_title = False
    
    __marked_text = ""

    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, original_language):
        HTMLParser.HTMLParser.__init__(self)

        self.__marked_text = ""
        self.__in_marked_paragarph = False
        self.__data_between_markers = ""
        
        self.__in_body = False
        self.__in_title = False
        self.__in_script = False

        self.__text_buffer = TA_html_text_buffer(original_language, default_encoding)
        
        self.__paragraph_lines = {}
        
        self.__marker_id = 0

        self.__external_references = []
        
        self.__file_name = ""

        self.__last_tag = ""
        
        self.__links = []

    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def handle_starttag(self, tag, attrs):

        tag = tag.lower()
        
        if tag == "body":
            self.__in_body = True

        if tag == "title":
            self.__in_title = True

        if not self.__in_script and (self.__in_body or tag == "title"):                
            if tag in paragraph_tags:
                
                # This is a paragraph start tag.
                
                if self.__in_marked_paragarph:
                    
                    self.__add_end_marker()
                    self.__in_marked_paragarph = False

        if tag in special_tags:
            self.__marked_text += start_marker
            
        self.__marked_text += "<%s" % tag
        for attr in attrs:
            if tag == "meta" and attr[0] == "content" and attr[1].startswith("text/html; charset="):
                
                # record the encoding and mark the spot that the character set is.
                
                char_set = attr[1][len("text/html; charset="):]
                self.__text_buffer.set_encoding(char_set)
                self.__marked_text += ' %s="%s"' % (attr[0], "text/html; charset=%s" % char_set_marker)
            elif tag == "meta" and attr[0] == "content":
                # see if we have a "name"
                name = None
                for attr_test in attrs:
                    if attr_test[0].lower() == "name":
                        name = attr_test[1]
                        break
                    
                if name != None:
                    self.__marked_text += " " + attr[0] + '="'
                    self.__marked_text += start_marker
                    self.__marked_text += '%s%s%s%s' % (meta_name_marker, name, meta_name_marker, attr[1])
                    self.__marked_text += end_marker + '"'
                else:
                    self.__marked_text += ' %s="%s"' % (attr[0], attr[1])
            else:
                self.__marked_text += ' %s="%s"' % (attr[0], attr[1])
        self.__marked_text += ">"

        if tag in special_tags:
            self.__marked_text += end_marker
            
        
        if tag == "script":
            self.__in_script = True


        if not self.__in_script and (self.__in_body or tag == "title"):
            if tag in paragraph_tags:
                
                # This is a paragraph start tag.
    
                self.__in_marked_paragarph = True
                
                self.__marked_text += start_marker
                
                if tag == "title":
                    self.__marked_text += title_marker
                
            
        if tag in special_tags:
            for attr in attrs:
                if attr[0] == special_tags_attributes[tag]:
                    if len(attr[1]) > 0 and not attr[1].isspace():
                        self.__data_between_markers += attr[1]
            

        if tag == "body":
            self.__in_body = True

            # this is the start of the body we need to mark it as text
            # may follow which should then be part of a sentence.
            
            self.__in_marked_paragarph = True
            self.__marked_text += start_marker
        


        attr_to_get = ""        
            
        if tag == 'img' or tag == 'script':
            attr_to_get = 'src'
        elif tag == 'link':
            attr_to_get = 'href'
            
        if len(attr_to_get):
            
            for attr in attrs:
                if attr[0] == attr_to_get:
                    self.__external_references.append(attr[1])
            
        # get any external links.
        
        if tag == 'a':
            for attr in attrs:
                if attr[0] == "href":
                    if attr[1] not in self.__links:
                        self.__links.append(attr[1])
                        
        self.__last_tag = tag

            

        #----------------------------------------------------------------------
    def handle_endtag(self, tag):

        tag = tag.lower()
        
        if self.__in_marked_paragarph:
            if self.__in_body or tag == "title":                
                if tag in paragraph_tags:
                    
                    # This is a paragraph end tag.
                    
                    self.__add_end_marker()
                    self.__in_marked_paragarph = False
    
        move_start_marker = False
        if self.__marked_text.endswith(start_marker):
            self.__marked_text = self.__marked_text[:-len(start_marker)]
            move_start_marker = True
        
        self.__marked_text += "</%s>" % tag
        
        #print self.__marked_text
        #print self.__marked_text.endswith("\n")
        
        if move_start_marker:
            self.__marked_text += start_marker

        if tag == "script":
            self.__in_script = False


        if self.__in_body and not self.__in_script:                
            if tag in paragraph_tags:
                
                # This is a paragraph start tag.
    
                self.__in_marked_paragarph = True
                
                self.__marked_text += start_marker
                

        if tag == "body":
            self.__in_body = False

        if tag == "title":
            self.__in_title = False

            

        #----------------------------------------------------------------------
    def handle_data(self, data):
        if self.__in_marked_paragarph and not self.__in_title:
            
            # try to split into sentences.
            
            # find the first break character.
            
            end_sentence = -1
            for char in sentence_breaks:
                break_pos = data.find(char)
                if break_pos != -1:
                    if end_sentence == -1:
                        end_sentence = break_pos
                    else:
                        end_sentence = min(end_sentence, break_pos)

            if end_sentence == -1:
                # check for case of the line ending with a full stop.
                if data[-1] == ".":
                    end_sentence = len(data) - 1
                
            if end_sentence >= 0:
                sentence = data[:end_sentence + 1]
                self.__marked_text += sentence
                self.__marked_text += end_marker
                self.__marked_text += start_marker
                data = data[end_sentence + 1:]
                if len(data):
                    self.handle_data(data)
            else:
                self.__marked_text += data

        else:
            self.__marked_text += data
        
        #self.__marked_text += data
        self.__data_between_markers += data

        

        #----------------------------------------------------------------------
    def handle_comment(self, data):
        self.__marked_text += "<!--%s-->" % data
        pass

        #----------------------------------------------------------------------
    def handle_decl(self, decl):
        self.__marked_text += "<!%s>" % decl
        
        #----------------------------------------------------------------------
    def handle_charref(self, name):
        #print "charref %s" % name
        pass
        
        #----------------------------------------------------------------------
    def handle_entityref(self, name):
        try:
            htmlentitydefs.name2codepoint[name]
            self.__marked_text += "&%s;" % name
        except:
            self.__marked_text += "&%s" % name
        

        #char = unichr(htmlentitydefs.name2codepoint[name])
        #
        #self.__marked_text += char.encode(self.__text_buffer.get_encoding())
        
        #----------------------------------------------------------------------
    def handle_pi(self, data):
        self.__marked_text += "<?%s>" % data
        
        #----------------------------------------------------------------------
    def extract(self, file_name, stream):
        
        self.__file_name = file_name

        self.__marker_id = 0

        self.feed(stream)
        
        if self.__marked_text.rfind(start_marker) > self.__marked_text.rfind(end_marker):
            self.__remove_last_start_marker()
        
        output = self.__marked_text
            
        self.__text_buffer.set_file_name(file_name)
        
        self.__text_buffer.store_marked_file(output)
        
        self.__store_paragraphs_in_text_buffer(output)
        
        self.__add_external_references_to_text_buffer()
        
        return self.__text_buffer
        
        #----------------------------------------------------------------------
    def get_found_links(self):
        return self.__links
    
    # PRIVATE FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def __add_end_marker(self):
        
        if self.__marked_text.endswith(start_marker):
            self.__marked_text = self.__marked_text[:-(len(start_marker))]
        else:
            if len(self.__data_between_markers) == 0 or self.__data_between_markers.isspace():
                self.__remove_last_start_marker()
            else:
                self.__marked_text += end_marker

        self.__data_between_markers = ""
        
        #----------------------------------------------------------------------
    def __remove_last_start_marker(self):
        
        position = self.__marked_text.rfind(start_marker)
        if position >= 0:
            self.__marked_text = self.__marked_text[:position] + self.__marked_text[position + len(start_marker):]

        

        #----------------------------------------------------------------------
    def __store_paragraphs_in_text_buffer(self, output):

        # search for the start and end paragraph markers and
        # record in a list.
        
        paragraph_markers = []
        
        size = len(output) - len(start_marker)
        for i in range(size):
            
            open_found = True
            for step in range(len(start_marker)):
                if output[i + step] != start_marker[step]:
                    open_found = False
                    break
                
            close_found = True
            for step in range(len(end_marker)):
                if output[i + step] != end_marker[step]:
                    close_found = False
                    break
                
            if open_found:
                paragraph_markers.append(i)
                
            if close_found:
                paragraph_markers.append(i)
                
        
        #print len(paragraph_markers)
        for i in range(0, len(paragraph_markers), 2):
            start = paragraph_markers[i]
            end = paragraph_markers[i + 1]
            text = output[start + len(start_marker) : end]
            
            #print ">>>>>", text
            #
            #if text.find('<img src="../images/here.gif" alt="') >= 0:
            #    print text
            
            self.__text_buffer.add_paragraph(start, end, text)
            
            
        

        #----------------------------------------------------------------------
    def __join_path(self, root, file):
        if root.startswith("http:"):
            return root + "/" + file
        else:
            return os.path.join(root, file)

        #----------------------------------------------------------------------
    def __add_external_references_to_text_buffer(self):
        
        from urlparse import urlparse
        
        for ref in self.__external_references:
            
            parts = urlparse(ref)

            if parts[0] == '' and parts[1] == '':
                self.__text_buffer.store_support_file("", ref)
                
                if ref.lower().endswith(".css"):
                    
                    import css_scanner
                    finder = css_scanner.CSS_scanner(self.__file_name.startswith("http:"))
                    #print "CSS " + ref
                    
                    finder.process(self.__join_path(os.path.dirname(self.__file_name), ref))
                    for css_image in finder.get_files():
                        self.__text_buffer.store_support_file(
                                os.path.dirname(ref), css_image)
                        
                    
                
        
                        
        #----------------------------------------------------------------------
    def __next_id(self):
        self.__marker_id += 1
        return self.__marker_id
                    
            
    
        
        
if __name__ == "__main__":
    
    extractor = TA_html_extractor("english")
    
    from urllib import urlopen
    #full_file_name = "http://www.heaventools.com/index.htm"
    #full_file_name = "http://www.bcainc.org/index.html"
    #full_file_name = "http://www.digitalpeers.com/Contact_us.htm"
    #full_file_name = "http://www.heaventools.com/pr_051407_heaventools.htm"
    #full_file_name = "http://www.perfecttableplan.com/index.html"
    full_file_name = "http://www.hostelladanesa.com/index.html"
    
    file_data = urlopen(full_file_name).read()
    print file_data

    text_buffer = extractor.extract(full_file_name, file_data)
    
    for i in range(text_buffer.get_paragraph_count()):
        paragraph = text_buffer.get_paragraph(i)
    
        if paragraph.has_text():
            paragraph_text = paragraph.get_text(text_buffer.get_original_language())
            
            print paragraph_text
    
    print "LINKS"
    for link in extractor.get_found_links():
        print link
        
    #text_buffer = extractor.extract("c:\\temp\\contactus_2.html", open("c:\\temp\\contactus_2.html", "r").read())

    
    #print text_buffer.get_marked_file()
    
    #print text_buffer.get_non_blank_paragraph_and_word_count(-1)
    
    #text_buffer = extractor.extract("Test files/ruby.htm", open("Test files/ruby.htm", "r").read())
    #text_buffer = extractor.extract("Test files/php.htm", open("Test files/php.htm", "r").read())

    #from TA_html_reconstructor import TA_html_reconstructor
    
    #reconstructor = TA_html_reconstructor()


    #print reconstructor.reconstruct_document(text_buffer, "English", "utf-8")
    #print reconstructor.reconstruct_document(text_buffer, "French", "utf-8")
    
