import TA_html_extractor

f = open('../test/sample1/contact.html','r')
txt = f.read()
f.close()

extractor = TA_html_extractor.TA_html_extractor("english")
text_buffer = extractor.extract('contact.html', txt)
for i in range(text_buffer.get_paragraph_count()):
    paragraph = text_buffer.get_paragraph(i)
    
    if paragraph.has_text():
        paragraph_text = paragraph.get_text(text_buffer.get_original_language())
        print paragraph_text
