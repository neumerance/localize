# TA_text_buffer.py

import time
import copy
from xml.etree.cElementTree import Element, SubElement

class TA_text_block:
    """ This is the actual text data to be translated."""
    
    # DATA ####################################################################
    
    __text_data = {}    # a dictionary with a key to each translation.
    __original_language = ""
    __encoding = ""

    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, text, original_language, encoding):
        self.__text_data = {}
        self.__translation_status = {}
        self.__from_translation_memory = {}
        
        self.__encoding = encoding
        self.__original_language = original_language
        self.__text_data[original_language] = unicode(text, encoding)
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def reconstruct(self, language, encoding, reconstructor, selected):
        
        try:
            return reconstructor.process_text(self.__text_data[language].encode(encoding),
                                                selected)
        except:
            return "~EEE error in text block EEE~"
        
        
        #----------------------------------------------------------------------
    def get(self, language):
        return self.__text_data[language]
        
        #----------------------------------------------------------------------
    def has_text(self):
        return not self.__text_data[self.__original_language].isspace()
    
        #----------------------------------------------------------------------
    def is_text(self):
        return True
    
        #----------------------------------------------------------------------
    def set_text(self, language, text):
        if text != self.__text_data[language]:
            self.__text_data[language] = text
            return True
        else:
            return False

        #----------------------------------------------------------------------
    def add_language(self, language):

        # make sure we dont have the language already
        
        if language in self.__text_data.keys():
            return False
        else:
            self.__text_data[language] = self.__text_data[self.__original_language]
            return True
        
        #----------------------------------------------------------------------
    def merge_from(self, block_to_merge):
        for lang in block_to_merge.__text_data.keys():
            if lang != self.__original_language:
                self.__text_data[lang] = block_to_merge.__text_data[lang]
                
        
        
        #----------------------------------------------------------------------
    def __repr__(self):
        return str(self.__text_data)
    
class TA_text_format_marker:
    """ This is a format marker that is part of the paragraph."""
    
    # DATA ####################################################################
    

    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self):
        pass
        
    # PUBLIC FUNCTIONS ########################################################

        #======================================================================
        # Functions that should overriden
        #======================================================================

        #----------------------------------------------------------------------
    def is_start_marker(self):
        pass
    
        #----------------------------------------------------------------------
    def get_marker_id(self):
        return 0
    
        #----------------------------------------------------------------------
    def get_color(self):
        return wxNameColor('RED')
    
        #----------------------------------------------------------------------
    def get_short_description(self):
        return "None"
    
        #----------------------------------------------------------------------
    def get_type(self):
        return "no type defined"

    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def is_end_marker(self):
        return not self.is_start_marker()

        #----------------------------------------------------------------------
    def has_text(self):
        return False
    
        #----------------------------------------------------------------------
    def is_text(self):
        return False


# Function ####################################################################

def are_marker_types_same(marker_list_1, marker_list_2):

    if len(marker_list_2) != len(marker_list_1):
        return False
    
    for i in range(len(marker_list_1)):
        if str(marker_list_1[i][1]) != str(marker_list_2[i][1]):
            return False
        
    return True
    
    
    
# Function ####################################################################

def save_marker_list(xml_parent, marker_list):

    marker_start_positions = {}
    
    for marker_item in marker_list:
        if marker_item[1].is_start_marker():
            # record position of start marker 
            marker_start_positions[marker_item[1].get_marker_id()] = marker_item[0]
            SubElement(xml_parent, "marker", {"id" : "%i" % marker_item[1].get_marker_id(),
                                                      "start" : "%i" % marker_item[0],
                                                      "end" : "-1"})
        else:
            # end marker.
            if marker_start_positions.has_key(marker_item[1].get_marker_id()):
                # marker has a matching start marker
                for marker in xml_parent.getiterator("marker"):
                    if marker_item[1].get_marker_id() == int(marker.get("id")):
                        marker.attrib["end"] = "%i" % marker_item[0]
                        pass


                del marker_start_positions[marker_item[1].get_marker_id()]
            else:
                # there is no matching start marker in the sentence.
                marker = SubElement(xml_parent, "marker", {"id" : "%i" % marker_item[1].get_marker_id(),
                                                          "start" : "-1",
                                                          "end" : "%i" % marker_item[0]})
                    
            
    # output any open markers
    # these are start markers that don't have a matching end in the sentence

    for key in marker_start_positions.keys():
        
        marker = SubElement(xml_parent, "marker", {"id" : "%i" % key,
                                                "start" : "%i" % marker_start_positions[key],
                                                "end" : "-1"})


# Function ####################################################################

def save_markers(xml_parent, marker_list):
                
    if len(marker_list) > 0:
        
            
        for marker_item in marker_list:

            # output if it is a start marker or if the id is negative. A negative
            # id indicates that it is an end marker with no matching start marker.
            # this can happen eg.  <a ref="xxx">some text<br>more text</a>
            
            if marker_item[1].is_start_marker() or marker_item[1].get_marker_id() < 0:
                marker = SubElement(xml_parent, "marker_def", {"id" : "%i" % marker_item[1].get_marker_id(),
                                                         "type" : marker_item[1].get_type()})
                marker_item[1].save(marker)
                    
                
    
    
class TA_text_paragraph:
    """ base class for a paragraph of text. This contains text to be
        translated include any formating markers."""
    
    # DATA ####################################################################

    __text_data = {}    # a dictionary with a key to each translation.
    __original_language = ""
    __encoding = "" # encoding of the original document
    
    __current_position = 0 # position of last character added
    __markers = {}  # a dictionary for languages with list of
                    # pairs of [position, markers]
    
    __translation_status = {}  # a dictionary with status and time.
    __from_translation_memory = {}
    __comments = "" # comments for this paragraph
    __required_text = [] # a list of text required in the paragraph

    __revision_id = {}  # a dictionary for revision id for each language
    
    __dirty = False  # indicates if the text buffer has been changed since the
                        # last save.

    __type = ""  # usually "" or "title" or "meta:name"    

    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, original_language, encoding):
        self.__original_language = original_language
        self.__encoding = encoding
        
        self.__text_data = {}
        self.__text_data[original_language] = u""
        
        self.__space_before = u""
        self.__space_after = u""

        self.__translation_status = {}
        self.__translation_status[self.__original_language] = ("New", time.time())
        
        self.__from_translation_memory = {}
        self.__from_translation_memory[self.__original_language] = False
        
        self.__current_position = 0
        self.__markers = {}
        self.__markers[original_language] = []
        
        self.__do_translation = True
        self.__comments = ""
        self.__required_text = []
        self.__dirty = False
        
        self.__type = ""
        
        self.__revision_id = {}
        
        self.__id = -1
        
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def set_id(self, id):
        self.__id = id
    
        #----------------------------------------------------------------------
    def set_revision_id(self, id, language):
        self.__revision_id[language] = id
    
        #----------------------------------------------------------------------
    def get_revision_id(self, language):
        try:
            return self.__revision_id[language]
        except:
            return -1
    
        #----------------------------------------------------------------------
    def set_type_as_title(self):
        self.__type = "title"

        #----------------------------------------------------------------------
    def is_title(self):
        return self.__type == "title"
        
        #----------------------------------------------------------------------
    def set_type_as_meta(self, name):
        self.__type = "meta:%s" % name

        #----------------------------------------------------------------------
    def is_meta_data(self):
        return self.__type.startswith("meta:")
        
        #----------------------------------------------------------------------
    def get_meta_data(self):
        if self.__type.startswith("meta:"):
            return self.__type[len("meta:"):]
        else:
            return ""
        
        #----------------------------------------------------------------------
    def save(self, root, clear_dirty_state = True):
        """ save the text buffer to an xml file"""

        # save the root for a sentence.
        
        do_translation_state = "no"
        if self.__do_translation:
            do_translation_state = "yes"
            
        attributes = {"original_language" : self.__original_language,
                                                    "encoding" : self.__encoding,
                                                    "format" : "1",
                                                    "do_translation" : do_translation_state,
                                                    "id" : str(self.__id)
                                                    }
        
        if self.is_title():
            attributes["type"] = "title"
        elif self.is_meta_data():
            attributes["type"] = "meta"
            attributes["meta_name"] = self.get_meta_data()
            
        sentence = SubElement(root, "ta_sentence", attributes)

        # save the space before
        
        space_before = SubElement(sentence, "space_before")
        space_before.text = self.__space_before
        
        # save the space after
        
        space_after = SubElement(sentence, "space_after")
        space_after.text = self.__space_after
        
        # save the text data.
        
        for key in self.__text_data.keys():
            # save for each language.
            attrs = {"language" : key}
            text_data = SubElement(sentence, "text_data", attrs)
            try:
                attrs = {"status" : self.__translation_status[key][0],
                                                  "time" : "%i" % self.__translation_status[key][1]}
                if self.__revision_id.has_key(key):
                    attrs["rev_id"] = str(self.__revision_id[key])
                    
                if self.__from_translation_memory.has_key(key):
                    attrs["from_TM"] = str(self.__from_translation_memory[key])
                    
                text = SubElement(text_data, "text", attrs)
            except:
                text = SubElement(text_data, "text", {"status" : "xxxx",
                                                  "time" : "xxxx"})
            text.text = self.__text_data[key]

            # save the marker positions.
            marker_list = self.__markers[key]
            
            save_marker_list(text_data, marker_list)
            
        # save the markers.

        marker_list = self.__markers[self.__original_language]
        save_markers(sentence, marker_list)
                        
        
        # save comments.
        
        if len(self.__comments) > 0:        
            comments = SubElement(sentence, "comments")
            comments.text = self.__comments

        # save required texts.
        
        if len(self.__required_text) > 0:        
            required = SubElement(sentence, "required")
            for text in self.__required_text:
                text_element = SubElement(required, "text")
                text_element.text = text
        
        if clear_dirty_state:
            self.__dirty = False
                              
        #----------------------------------------------------------------------
    def load(self, xml_data, marker_loader):
        """ load the sentence buffer from an xml file"""

        # load the do translation state.
        do_translation_state = xml_data.get("do_translation")
        if do_translation_state == "no":
            self.__do_translation = False
        else:
            # all other states are true
            self.__do_translation = True
        
        try:
            self.__id = int(xml_data.get('id'))
        except:
            self.__id = -1

        if xml_data.get("type") != None:
            self.__type = xml_data.get("type")
            
        if xml_data.get("meta_name") != None:
            self.__type += ":" + xml_data.get("meta_name")
            
            
        # load the marker definitions.
        
        loaded_markers = {}
        
        markers_xml = xml_data.getiterator("marker_def")
        
        for marker_xml in markers_xml:
            marker = marker_loader.load(marker_xml)
            loaded_markers[marker.get_marker_id()] = marker
                    
        
        # load the space before
        
        self.__space_before = u""

        space_before = xml_data.find("space_before")
        try:
            self.__space_before = space_before.text
            if self.__space_before == None:
                self.__space_before = u""
        except:
            pass
        
        # load the space after
        
        self.__space_after = u""

        space_after = xml_data.find("space_after")
        try:
            self.__space_after = space_after.text
            if self.__space_after == None:
                self.__space_after = u""
        except:
            pass
        
        # load the text data.
        
        for text_data in xml_data.getiterator("text_data"):

            text_xml = text_data.find("text")
            
            # load for each language.
            
            language = text_data.get("language")
            self.__text_data[language] = text_xml.text
            if self.__text_data[language] == None:
                self.__text_data[language] = u""
                
            revision_id = text_xml.get("rev_id")
            if revision_id != None:
                self.__revision_id[language] = int(revision_id)
            
            self.__translation_status[language] = (text_xml.get("status"), int(text_xml.get("time")))
            
            if text_xml.get("from_TM"):
                self.__from_translation_memory[language] = text_xml.get("from_TM") == "True"
    
            # load the markers.

            self.__markers[language] = []

            marker_end_positions = []
            
            for marker_xml in text_data.getiterator("marker"):
                start = int(marker_xml.get("start"))
                id = int(marker_xml.get("id"))

                # find matching end markers.
                
                while len(marker_end_positions) and marker_end_positions[-1][0] <= start:
                    end = marker_end_positions[-1][0]
                    if end >= 0:
                        marker = [end, marker_end_positions[-1][1].create_matching_end_marker()]
                        if marker not in self.__markers[language]:
                            self.__markers[language].append(marker)
                    del marker_end_positions[-1]
                    
                # load the start marker
                
                if start >= 0:
                    marker = [start, loaded_markers[id]]
                    if marker not in self.__markers[language]:
                        self.__markers[language].append(marker)
                
                # record the end marker.
                marker_end_positions.append((int(marker_xml.get("end")), loaded_markers[id]))
                
            # output any end markers.
                
            while len(marker_end_positions):
                end = marker_end_positions[-1][0]
                if end >= 0:
                    marker = [end, marker_end_positions[-1][1].create_matching_end_marker()]
                    if marker not in self.__markers[language]:
                        self.__markers[language].append(marker)
                    
                del marker_end_positions[-1]
                
        # now sort the markers
            
        self.__sort_markers()
        
        
            
        # load any comments.
        
        comments = xml_data.find("comments")
        if comments != None:
            self.__comments = comments.text
            
        # load any requirements.
        
        requirements = xml_data.find("required")
        if requirements != None:
            
            for required in requirements.getiterator("text"):
                self.__required_text.append(required.text)
            
            
        self.__dirty = False

        #----------------------------------------------------------------------
    def add_text(self, text):
        try:
            unicode_text = unicode(text, self.__encoding, 'replace')
        except:
            unicode_text = unicode(text, "utf-8", 'replace')
            
        self.__text_data[self.__original_language] += unicode_text 
        self.__current_position += len(unicode_text)
        self.__translation_status[self.__original_language] = ("New", time.time())

        self.__dirty = True
        
        #----------------------------------------------------------------------
    def add_unicode(self, text):
        self.__text_data[self.__original_language] += text
        self.__current_position += len(text)
        self.__translation_status[self.__original_language] = ("New", time.time())
        
        self.__dirty = True

        #----------------------------------------------------------------------
    def add_marker(self, marker):
        self.__markers[self.__original_language].append([self.__current_position, marker])

        self.__dirty = True
        
        #----------------------------------------------------------------------
    def separate_leading_and_trailing_spaces(self):
        
        if len(self.__markers[self.__original_language]) > 0:
            first_marker = self.__markers[self.__original_language][0][0]
        else:
            first_marker = len(self.__text_data[self.__original_language])
            
        self.__space_before = u""
        
        for i in range(first_marker):
            char = self.__text_data[self.__original_language][i]
            if char.isspace() or char == 0x00a0: # nbsp
                self.__space_before += char
            else:
                break
            
        # if we have found any white space before the text then adjust the markers
        
        space_before_length = len(self.__space_before)
        
        if space_before_length > 0:
            self.__text_data[self.__original_language] = self.__text_data[self.__original_language][space_before_length:]
            if len(self.__markers[self.__original_language]) > 0:
                
                temp_markers = []
                for marker in self.__markers[self.__original_language]:
                    temp_markers.append([marker[0] - space_before_length, marker[1]])
                    
                self.__markers[self.__original_language] = temp_markers
            
                
        
        
        
        self.__space_after = u""
        
        #----------------------------------------------------------------------
    def reconstruct(self, language, encoding, reconstructor, selected):
        output = ""

        if len(self.__space_before) > 0:
            # output the space before text.
            output += reconstructor.process_text(self.__space_before.encode(encoding),
                                                selected)
        
        current_position = 0
        
        index = 0
        while index < len(self.__markers[language]):
            marker_position = self.__markers[language][index][0]
            
            if current_position == marker_position:
                output += self.__markers[language][index][1].reconstruct(language, encoding, reconstructor, selected)
                index += 1
            else:
                # output from the current position to the marker position.
                text = self.__text_data[language][current_position : marker_position]
                output += reconstructor.process_text(text.encode(encoding),
                                                    selected)
            current_position = marker_position
            
        # output from the current position to the end
        
        try:
            length = len(self.__text_data[language])
            if current_position != length:
                text = self.__text_data[language][current_position : len(self.__text_data[language])]
                output += reconstructor.process_text(text.encode(encoding),
                                                    selected)
        except:
            output += "~EEE error in text block EEE~"
        
        
        return output
    
        #----------------------------------------------------------------------
    def get_text(self, language):
        return self.__text_data[language]
        
        #----------------------------------------------------------------------
    def get_marker(self, language, index):
        
        # return position and marker
        
        if index < len(self.__markers[language]):
            return self.__markers[language][index][0], self.__markers[language][index][1]
        else:
            return -1, None
        
        #----------------------------------------------------------------------
    def get_marker_count(self, language):
        return len(self.__markers[language])
        
        #----------------------------------------------------------------------
    def get_markers(self, language):
        markers = []
    
        marker_count = self.get_marker_count(language)
    
        for index in range(marker_count):
            markers.append(self.get_marker(language, index))
        
        return markers
    
        #----------------------------------------------------------------------
    def __sort_markers(self):
        
        def marker_sort(m1, m2):
            if m1[0] > m2[0]:
                return 1
            elif m1[0] == m2[0]:
                return 0
            else: # <
                return -1
            
        for language in self.__markers.keys():
            self.__markers[language].sort(marker_sort)
            
        #----------------------------------------------------------------------
    def get_markers_as_text(self):
        text = "<TA_markers>"
        
        for marker in self.__markers[self.__original_language]:
            text += str(marker)
        
        text += "</TA_markers>"        
        return text

        #----------------------------------------------------------------------
    def has_text(self):
        return len(self.__text_data[self.__original_language]) > 0 and \
                    not self.__text_data[self.__original_language].isspace()
        
        #----------------------------------------------------------------------
    def set_text(self, language, text, update_status = True):
        if self.__text_data[language] == text:
            # nothing has changed
            #if update_status:
            #    self.__translation_status[language] = ("Modified", time.time())
            return
        
        self.__text_data[language] = text
        if update_status:
            self.__translation_status[language] = ("Modified", time.time())

        self.__dirty = True

        #----------------------------------------------------------------------
    def clear_markers(self, language):
        self.__markers[language] = []

        self.__dirty = True

        #----------------------------------------------------------------------
    def set_marker(self, language, position, marker):
        self.__markers[language].append([position, marker])

        self.__dirty = True

        #----------------------------------------------------------------------
    def set_markers(self, language, markers):
        old_dirty_state = self.__dirty
        markers_before = copy.deepcopy(self.__markers[language])
        
        self.clear_markers(language)
        
        for marker in markers:
            self.set_marker(language, marker[0], marker[1])
         
        if markers_before == self.__markers[language]:
            # nothing has changed
            self.__dirty = old_dirty_state

        #----------------------------------------------------------------------
    def append(self, other_sentence):
        for language in self.__text_data.keys():
            original_length = len(self.__text_data[language])
            
            self.__text_data[language] += self.__space_after + other_sentence.__space_before + other_sentence.__text_data[language]
            
            for marker in other_sentence.__markers[language]:
                self.set_marker(language, marker[0] + original_length, marker[1])
                
            self.__translation_status[language] = ("Modified", time.time())

        self.__space_after = other_sentence.__space_after

        self.__dirty = True

        #----------------------------------------------------------------------
    def clear_sentence(self):
        for language in self.__text_data.keys():
            self.__text_data[language] = ""
            
            self.__markers[language] = []

            self.__translation_status[language] = ("Modified", time.time())

        self.__space_after = ""
        self.__space_before = ""
        
        self.__dirty = True

        #----------------------------------------------------------------------
    def is_translated(self, language):
        return self.__translation_status[language][0] == "Complete"
        
        #----------------------------------------------------------------------
    def is_modified(self, language):
        return self.__translation_status[language][0] == "Modified"
        
        #----------------------------------------------------------------------
    def get_sentence_status(self, language):
        return self.__translation_status[language][0]
    
        #----------------------------------------------------------------------
    def set_sentence_status(self, language, status):
        self.__translation_status[language] = (status, self.__translation_status[language][1])
    
        #----------------------------------------------------------------------
    def mark_translation_complete(self, language):
        self.__translation_status[language] = ("Complete", time.time())

        self.__from_translation_memory[language] = False

        self.__dirty = True
        
        #----------------------------------------------------------------------
    def mark_translation_modified(self, language):
        self.__translation_status[language] = ("Modified", time.time())

        self.__dirty = True
        
        #----------------------------------------------------------------------
    def mark_as_from_translation_memory(self, language):
        self.__from_translation_memory[language] = True
        
        self.__dirty

        #----------------------------------------------------------------------
    def is_from_translation_memory(self, language):
        try:
            return self.__from_translation_memory[language]
        except:
            return False
        
        #----------------------------------------------------------------------
    def set_to_be_translated_state(self, state):
        self.__do_translation = state
        
        self.__dirty = True

        #----------------------------------------------------------------------
    def should_be_translated(self):
        return self.__do_translation
        
        #----------------------------------------------------------------------
    def add_language(self, language, revision_id = None):

        # make sure we dont have the language already
        
        if language in self.__text_data.keys():
            return False
        else:
            self.__translation_status[language] = ("New", time.time())

            self.__text_data[language] = self.__text_data[self.__original_language]
            self.__markers[language] = self.__markers[self.__original_language][:]
            
            try:
                if revision_id == None:
                    self.__revision_id[language] = self.__revision_id[self.__original_language]
                else:
                    self.__revision_id[language] = revision_id
            except:
                self.__revision_id[language] = -1

            self.__dirty = True

            return True
                

        #----------------------------------------------------------------------
    def merge_from(self, paragraph_to_merge):
        for lang in paragraph_to_merge.__text_data.keys():
            if lang != self.__original_language:
                self.__text_data[lang] = paragraph_to_merge.__text_data[lang]
                self.__markers[lang] = paragraph_to_merge.__markers[lang]
                self.__translation_status[lang] = paragraph_to_merge.__translation_status[lang]
        
        #----------------------------------------------------------------------
    def copy_translations(self, paragraph_with_translations):
        for lang in paragraph_with_translations.__text_data.keys():
            if lang != self.__original_language:
                self.__text_data[lang] = paragraph_with_translations.__text_data[lang]
                self.__markers[lang] = paragraph_with_translations.__markers[lang]
                self.__translation_status[lang] = ("Modified", time.time())
                
        self.__comments = paragraph_with_translations.__comments
            
        self.__required_text = paragraph_with_translations.__required_text
        
        #----------------------------------------------------------------------
    def add_to_translation_memory(self, translation_memory):

        if self.has_text():
            original_text = self.get_text(self.__original_language)
        
            marker_count = self.get_marker_count(self.__original_language)
            original_markers = []
            for index in range(marker_count):
                original_markers.append(self.get_marker(self.__original_language, index))
            
            for lang in self.__text_data.keys():
                
                if self.is_translated(lang):
                    translated_text = self.get_text(lang)
            
                    translated_markers = []
                    for index in range(marker_count):
                        translated_markers.append(self.get_marker(lang, index))
                    
                    translation_memory.save_translation(lang, original_text, tuple(original_markers),
                                                        translated_text, tuple(translated_markers))
        
        
        #----------------------------------------------------------------------
    def copy_original_markers_to_translations(self):
        for lang in self.__text_data.keys():
            if lang != self.__original_language:
                self.__markers[lang] = self.__markers[self.__original_language]
                
        #----------------------------------------------------------------------
    def set_comments(self, comments):
        if comments != self.__comments:
            self.__comments = comments

            self.__dirty = True
    
        #----------------------------------------------------------------------
    def get_comments(self):
        return self.__comments

        #----------------------------------------------------------------------
    def add_required_text(self, text):
        if text not in self.__required_text:
            self.__required_text.append(text)

            self.__dirty = True

            return True
        else:
            return False
    
        #----------------------------------------------------------------------
    def remove_required_text(self, text):
        try:
            self.__required_text.remove(text)
        except:
            pass
    
        self.__dirty = True

        #----------------------------------------------------------------------
    def get_required_text(self):
        return self.__required_text
    
        #----------------------------------------------------------------------
    def is_dirty(self):
        return self.__dirty
    
        #----------------------------------------------------------------------
    def __repr__(self):
        
        return str(self.__text_data) + str(self.__markers) + " Dirty " + str(self.__dirty) + "comments : " + self.__comments
    
class TA_text_buffer:
    """ base class of the text buffer."""
    
    # DATA ####################################################################
    
    __text_data = [] # a list of text data, some of which will be paragraphs
                     # that require translation.
                     
    __languages = [] # a list of all languages that are required.
    __original_language = "" # the original language
    
    __dirty = False  # indicates if the text buffer has been changed since the
                        # last save.
    
    # CONSTRUCTORS ETC ########################################################
        
        #----------------------------------------------------------------------
    
    def __init__(self, original_language):
        self.__original_language = original_language
        self.__text_data = []
        self.__languages = []
        self.__modifided = False
        self.__change_data = {}
        
    # PUBLIC FUNCTIONS ########################################################

        #======================================================================
        # Functions that should overriden
        #======================================================================

        #----------------------------------------------------------------------
    def reload_new_version_from_source(self, compare_file):
        return None
    
    # PUBLIC FUNCTIONS ########################################################

        #----------------------------------------------------------------------
    def save(self, root, clear_dirty_state = True):
        """ save the text buffer to an xml file"""

        # save the languages.
        
        languages = SubElement(root, "languages")
        for language in self.__languages:
            lang = SubElement(languages, "language")
            lang.text = language

        # save each sentence.
        
        sentences = SubElement(root, "sentences", {"count" : "%i" % len(self.__text_data)})
        
        for sentence in self.__text_data:
            sentence.save(sentences, clear_dirty_state)

        self.__save_html_output_change_data(root)
        
        self.__modifided = False
    
        #----------------------------------------------------------------------
    def load(self, xml_data, marker_loader):
        """ load the text buffer from an xml file"""
        
        # load the languages
        
        languages = xml_data.find("languages")
        
        self.__languages = []
        
        for language in languages.getiterator("language"):
            self.__languages.append(language.text)
        
        # load the sentences
        
        sentences = xml_data.find("sentences")
        
        self.__text_data = []
        for sentence_xml in sentences.getiterator("ta_sentence"):
            sentence = TA_text_paragraph(sentence_xml.get("original_language"),
                                         sentence_xml.get("encoding"))
            
            sentence.load(sentence_xml, marker_loader)
            
            self.__text_data.append(sentence)

        self.__load_html_output_change_data(xml_data)
            
        self.__modifided = False

        #----------------------------------------------------------------------
    def get_original_language(self):
        return self.__original_language
    
        #----------------------------------------------------------------------
    def set_original_language(self, original_language):
        self.__original_language = original_language
    
        #----------------------------------------------------------------------
    def add_paragraph(self, data):
        data.separate_leading_and_trailing_spaces()
        self.__text_data.append(data)
        self.__modifided = True

       
        #----------------------------------------------------------------------
    def get_paragraph(self, index):
        return self.__text_data[index]

        #----------------------------------------------------------------------
    def can_paragraph_merge_with_next(self, index, next_index):
        return False
    
        #----------------------------------------------------------------------
    def merge_sentence_with_next(self, index, next_index):
        
        sentence = self.__text_data[index]
        next_sentence = self.__text_data[next_index]
        
        sentence.append(next_sentence)
        next_sentence.clear_sentence()

        # set the sentence status to new
        for language in self.__languages:
            sentence.set_sentence_status(language, "New")
            next_sentence.set_sentence_status(language, "New")

        sentence.set_sentence_status(self.__original_language, "New")
        next_sentence.set_sentence_status(self.__original_language, "New")
    
        #----------------------------------------------------------------------
    def get_paragraph_count(self):
        return len(self.__text_data)
    
        #----------------------------------------------------------------------
    def get_non_blank_paragraph_count(self):
        
        count = 0
        for data in self.__text_data:
            if data.has_text():
                count += 1
                
        return count
    
        #----------------------------------------------------------------------
    def get_non_blank_paragraph_and_word_count(self, revision_id):
        
        count = 0
        word_count = 0
        
        sentences = []
        for data in self.__text_data:
            if data.has_text() and \
                        data.get_revision_id(self.__original_language) == revision_id and \
                        data.should_be_translated():
                
                paragraph_text = data.get_text(self.__original_language)
                    
                if paragraph_text not in sentences:
                    sentences.append(paragraph_text)

                    count += 1
    
                    word_count += len(paragraph_text.split())
                
                
        return count, word_count
    
        #----------------------------------------------------------------------
    def add_to_translation_memory(self, translation_memory):
        for data in self.__text_data:
            data.add_to_translation_memory(translation_memory)
        
        #----------------------------------------------------------------------
    def add_language(self, language, revision_id = None):
        for data in self.__text_data:
            try:
                data.add_language(language, revision_id)
            except:
                pass

        self.__languages.append(language)
        self.__modifided = True
        
        #----------------------------------------------------------------------
    def get_languages(self):
        return self.__languages

        #----------------------------------------------------------------------
    def merge_from(self, buffer_to_merge):
        for i in range(len(self.__text_data)):
            self.__text_data[i].merge_from(buffer_to_merge.__text_data[i])
            
        other_languages = buffer_to_merge.get_languages()
        for language in other_languages:
            if language not in self.__languages:
                self.__languages.append(language)

        #----------------------------------------------------------------------
    def get_stats(self, language, revision_id):
        total_sentences = 0
        word_count = 0
        
        translated_sentences = 0
        modified_sentences = 0
        
        sentences = []
        
        for i in range(self.get_paragraph_count()):
            paragraph = self.get_paragraph(i)
        
            if paragraph.should_be_translated() and paragraph.has_text() and \
                                paragraph.get_revision_id(self.__original_language) == revision_id:
                paragraph_text = paragraph.get_text(self.__original_language)
                
                if paragraph_text not in sentences:
                    
                    sentences.append(paragraph_text)
                    
                    word_count += len(paragraph_text.split())
                    
                    total_sentences += 1
                    
                    if paragraph.is_translated(language):
                        translated_sentences += 1
                    if paragraph.is_modified(language):
                        modified_sentences += 1
                    

        return {"sentences" : total_sentences,
                "words" : word_count,
                "complete" : translated_sentences,
                "modified" : modified_sentences}
                

        #----------------------------------------------------------------------
    def get_complete_count(self, language, revision_id, count_duplicates = False, return_total = False):
        translated_sentences = 0
        sentence_count = 0

        sentences = []
        
        for i in range(self.get_paragraph_count()):
            paragraph = self.get_paragraph(i)
        
            if paragraph.should_be_translated() and paragraph.has_text() and \
                                paragraph.get_revision_id(self.__original_language) == revision_id:
                paragraph_text = paragraph.get_text(self.__original_language)
                
                sentence_count += 1
                if paragraph_text not in sentences or count_duplicates:
                    
                    sentences.append(paragraph_text)

                    if paragraph.is_translated(language):
                        translated_sentences += 1

        if return_total:
            return translated_sentences, sentence_count
        else:
            return translated_sentences
    
        #----------------------------------------------------------------------
    def get_non_blank_sentences(self, language = None,
                                        include_markers = False,
                                        encoding = None):

        if language == None:
            language = self.__original_language
            
        sentence_list = []
        for i in range(self.get_paragraph_count()):
            paragraph = self.get_paragraph(i)
        
            if paragraph.has_text():
                paragraph_text = paragraph.get_text(language)
                if encoding:
                    paragraph_text = paragraph_text.encode(encoding)
                    
                for j in range(len(paragraph_text)):
                    if not paragraph_text[j].isspace():
                        break

                marker_text = ""
                
                if include_markers:
                    marker_text += paragraph.get_markers_as_text()
                    
                sentence_list.append(paragraph_text + marker_text)
                
        return sentence_list
                
        #----------------------------------------------------------------------
    def get_non_blank_sentences_indexes(self):

        sentence_list = []
        for i in range(self.get_paragraph_count()):
            paragraph = self.get_paragraph(i)
        
            if paragraph.has_text():
                paragraph_text = paragraph.get_text(self.__original_language)
                for j in range(len(paragraph_text)):
                    if not paragraph_text[j].isspace():
                        break
                    
                sentence_list.append(i)
                
        return sentence_list
                
                    
        #----------------------------------------------------------------------
    def mark_all_blank_sentences_complete(self):
        for i in range(self.get_paragraph_count()):
            paragraph = self.get_paragraph(i)
        
            found = False
            
            if paragraph.has_text():
                paragraph_text = paragraph.get_text(self.__original_language)
                for j in range(len(paragraph_text)):
                    if not paragraph_text[j].isspace():
                        found = True
                        break
                    
            if not found:
                paragraph.mark_translation_complete(self.__original_language)
                for language in self.__languages:
                    paragraph.mark_translation_complete(language)
        
        #----------------------------------------------------------------------
    def get_changes(self, compare_file, language = None, include_markers = True, encoding = None):
        if language == None:
            language = self.__original_language

        # we need to handle the "nbsp" (non breaking space) character so that the compare works correctly
        # change any "nbsp" to a space character. (Maybe the "nbsp" should be converted to a space on text extraction.
        import htmlentitydefs
        nbsp_char = unichr(htmlentitydefs.name2codepoint["nbsp"])
            
        old_sentences = self.get_non_blank_sentences(language, include_markers, encoding)
        for i in range(len(old_sentences)):
            old_sentences[i] = old_sentences[i].replace(nbsp_char, " ")
        
        import types
        if type(compare_file) == types.StringType:
            new_version = self.reload_new_version_from_source(compare_file)
        else:
            new_version = compare_file
        
        new_sentences = new_version.get_non_blank_sentences(language, include_markers, encoding)
        for i in range(len(new_sentences)):
            new_sentences[i] = new_sentences[i].replace(nbsp_char, " ")
        
        import difflib
        
        diff = difflib.Differ()
        
        results = list(diff.compare(old_sentences, new_sentences))
        
        return results
    
        #----------------------------------------------------------------------
    def make_revision(self, original_buffer):
        """ We want to merge the translations from the original_buffer into
            this buffer."""

        # get the languages from the original buffer.
        other_languages = original_buffer.get_languages()
        for language in other_languages:
            if language not in self.__languages:
                self.__languages.append(language)

        # get old and new sentences
        old_sentences = original_buffer.get_non_blank_sentences(include_markers = True)
        old_sentences_indexes = original_buffer.get_non_blank_sentences_indexes()
        
        new_sentences = self.get_non_blank_sentences(include_markers = True)
        new_sentences_indexes = self.get_non_blank_sentences_indexes()
        
        # Find the difference in the sentences.
        # Note that the sentences have the marker information tagged on the
        # end so if a marker changes a difference will be detected.
        # once a difference is detected then we can determine if it is the
        # text, markers or both.
        
        import difflib
        
        diff = difflib.Differ()
        
        results = list(diff.compare(old_sentences, new_sentences))
        
        # results are in the form of:
        #  - Passport Photo and Photo Backup software by OnTheGoSoft
        #  + Passport Photo (Modified) and Photo Backup software by OnTheGoSoft
        #  ?               +++++++++++
        #  
        #  OnTheGoSoft
        #  OnTheGoSoft
        #  OnTheGoSoft
        #  Products
        #  - Downloads
        #  Buy
        #  + Uploads
        #  Contact
        #  - Do you need photos for a passport, license or ID?
        #  ?    ^^^
        #  + Do YOU need photos for a passport, license or ID?
        #  ?    ^^^

        """Rules:
            1.  If the result starts with a ' ' (space) then sentence has not
                changed, so just copy the translation.
            2.  If result starts with a '-' then check next result. If it is not
                a '+' or '?' then the sentence has been deleted. Otherwise the
                sentence has been modified so we need to copy the translation.
            3.  If result starts with a '+' and the next result is not a '?' then
                this is a new sentence so we need to just add the languages
        """
        
        original_line = 0   # track what line we are on in original
        new_line = 0        # track what line we are on in new
        
        deleted_sentences = []
        added_sentences = []
        
        ignore_next_plus = False
        
        # add an end line at the end of the results list. This way we don't
        # need to do any special handling of end cases.
        results.append("end")
        
        for i in range(len(results)):
            if results[i][0] == ' ':
                #1.  If the result starts with a ' ' (space) then sentence has not
                #    changed, so just copy the translation.
                try:
                    print "Same: %s" % results[i]
                    print old_sentences[original_line]
                    print original_buffer.get_paragraph(old_sentences_indexes[original_line]).get_text(self.__original_language)
                    print new_sentences[new_line]
                    print self.get_paragraph(new_sentences_indexes[new_line]).get_text(self.__original_language)
                except:
                    pass
                old_sentence = original_buffer.get_paragraph(old_sentences_indexes[original_line])
                self.__text_data[new_sentences_indexes[new_line]] = old_sentence
                original_line += 1
                new_line += 1
            elif results[i][0] == '-':
                #2.  If result starts with a '-' then check next result. If it is not
                #    a '+' or '?' then the sentence has been deleted. Otherwise the
                #    sentence has been modified so we need to copy the translation.
                if results[i + 1][0] == '+' or results[i + 1][0] == '?':
                    try:
                        print "Modified: %s" % results[i]
                        print old_sentences[original_line]
                        print original_buffer.get_paragraph(old_sentences_indexes[original_line]).get_text(self.__original_language)
                        print new_sentences[new_line]
                        print self.get_paragraph(new_sentences_indexes[new_line]).get_text(self.__original_language)
                    except:
                        pass
                    old_sentence = original_buffer.get_paragraph(old_sentences_indexes[original_line])
                    self.__text_data[new_sentences_indexes[new_line]].copy_translations(old_sentence)
                    self.__text_data[new_sentences_indexes[new_line]].copy_original_markers_to_translations()
                    original_line += 1
                    new_line += 1
                    ignore_next_plus = True
                else:
                    try:
                        print "Deleted: %s" % results[i]
                        print old_sentences[original_line]
                        print original_buffer.get_paragraph(old_sentences_indexes[original_line]).get_text(self.__original_language)
                    except:
                        pass
                    deleted_sentences.append(original_line)
                    original_line += 1
            elif results[i][0] == '+':
                if not ignore_next_plus:
                    #3.  If result starts with a '+' and the next result is not a '?' then
                    #    this is a new sentence so we need to just add the languages
                    if results[i + 1][0] != '?':
                        try:
                            print "New: %s" % results[i]
                        except:
                            pass
                        for language in self.__languages:
                            self.__text_data[new_sentences_indexes[new_line]].add_language(language)
                        added_sentences.append(new_line)
                        new_line += 1
                    else:
                        try:
                            print "New: %s" % results[i]
                        except:
                            pass
                else:
                    ignore_next_plus = False
                    
        # now we need to check to see if we have moved any sentences. This
        # will be indicated by an added sentence being the same as a deleted sentence.
        
        used_deleted = []
        for added_sentence in added_sentences:
            text = self.__text_data[new_sentences_indexes[added_sentence]].get_text(self.__original_language)
            
            for deleted_sentence in deleted_sentences:
                if deleted_sentence not in used_deleted:
                    deleted_text = original_buffer.get_paragraph(old_sentences_indexes[deleted_sentence]).get_text(self.__original_language)
                    
                    if deleted_text == text:
                        
                        # text is the same.
                        old_sentence = original_buffer.get_paragraph(old_sentences_indexes[deleted_sentence])
                        self.__text_data[new_sentences_indexes[added_sentence]] = old_sentence
                        
                        used_deleted.append(deleted_sentence)
                        break
                        
                                    
            
        # lastly we need to add languages to any blank sentences that wont have had
        # the languages added by the previous process.
        
        for i in range(len(self.__text_data)):
            for language in self.__languages:
                
                # this is a bit brute force but the add_language function
                # stops adding the language more than once.
                self.__text_data[i].add_language(language)

                    
        return
        
        #----------------------------------------------------------------------
    def set_html_output_changes(self, lang, change_data):
        self.__change_data[lang] = change_data
        self.__dirty = True
        
        #----------------------------------------------------------------------
    def get_html_output_changes(self, lang):
        if self.__change_data.has_key(lang):
            import copy
            return copy.deepcopy(self.__change_data[lang])
        else:
            return []

        #----------------------------------------------------------------------
    def copy_change_data(self, other_text_buffer):
        if other_text_buffer.__change_data:
            import copy
            self.__change_data = copy.deepcopy(other_text_buffer.__change_data)
        else:
            self.__change_data = None
    
        #----------------------------------------------------------------------
    def __load_html_output_change_data(self, root):
        change = root.find("html_output_change_data")
        
        self.__change_data = {}
        if change != None:
            for change_data_xml in change.getiterator("change_data"):
                
                change_list = []
                
                for change_item_xml in change_data_xml.getiterator("change_item"):
                    change_item = {"mode" : change_item_xml.get("mode")}
                    
                    if change_item["mode"] == "change":
                        change_item["from"] = change_item_xml.find("from").text
                        change_item["to"] = change_item_xml.find("to").text
    
                    if change_item["mode"] == "delete" or change_item["mode"] == "add":
                        change_item["data"] = change_item_xml.find("data").text
    
                    change_context_list = []
                    for change_context_xml in change_item_xml.find("context_list").getiterator("context"):
                        change_context_list.append(change_context_xml.text)
                        
                    change_item["context"] = change_context_list
                    
                    change_list.append(change_item)
                                   
                self.__change_data[change_data_xml.get("language")] = change_list
            
            
            
            
        #----------------------------------------------------------------------
    def __save_html_output_change_data(self, root):
        change = SubElement(root, "html_output_change_data")
        if self.__change_data:
            for lang in self.__change_data.keys():
                lang_change = SubElement(change, "change_data", {"language": lang})

                changes = self.get_html_output_changes(lang)
                for i in range(len(changes)):
                    change_item = SubElement(lang_change, "change_item", {"mode": changes[i]["mode"]})
                    
                    if changes[i]["mode"] == "change":
                        change_from = SubElement(change_item, "from")
                        change_from.text = changes[i]["from"]
                        change_to = SubElement(change_item, "to")
                        change_to.text = changes[i]["to"]

                    if changes[i]["mode"] == "delete" or changes[i]["mode"] == "add":
                        change_data = SubElement(change_item, "data")
                        change_data.text = changes[i]["data"]
                        
                    change_context_list = SubElement(change_item, "context_list")
                    for change_context in changes[i]["context"]:
                        change_context_item = SubElement(change_context_list, "context")
                        change_context_item.text = change_context
                
        

        #----------------------------------------------------------------------
    def is_dirty(self):
        if self.__dirty:
            return True
        
        # otherwise check each sentence.
        
        for i in range(self.get_paragraph_count()):
            paragraph = self.get_paragraph(i)
            if paragraph.is_dirty():
                return True
            
        # no changes found.
        
        return False
        
        
        
        
        #----------------------------------------------------------------------
    def __repr__(self):
        output = ""
        
        count = 0
        for data in self.__text_data:
            output += '%i - %s' % (count, str(data))
            output += "\n"
            
            count += 1
            
        return output

            