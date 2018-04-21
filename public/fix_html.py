# -*- coding: UTF-8 -*-

import os, string, urllib, sys, tarfile, time
import sitemap_gen

num_languages = 7
EN, DE, FR, ES, PT, ZU, IT = range(num_languages)
domain = "www.icanlocalize.com"

# this lists all the pages in the site.
# every pages goes under a certain tab, and has a certain path from the home page (top navigation)
# format:
# [tab name, first page under tab, [nested list of pages]]
site = [['Home','index.html',
         ['about.html', 'web-designers.html', 'get_quote.html']],
        ['Website Translation','website-translation.html',
         ['blog-translation.html','drupal-translation.html','free-trial-translation.html','client_overview.html','client_benefits.html','check_by_upload.html', 'tour1.html', 'tour2.html', 'tour3.html']],
        ['General Translation','general-translation.html', ['help-translation.html','sisulizer.html']],
        ['Text Translation','instant-text-translation.html', ['software_localization.html',['iphone_localization.html',['iphone_localization_guide.html']]]],
        ['Online Interpretation','customer-support-interpretation.html', ['support-ticket-system.html']]
        ]

homepage = 'index.html'

page_names = {"index.html" : "Home",
              "about.html" : "About ICanLocalize",
              "web-designers.html" : "Partnerships with Web Designers",
              "get_quote.html" : "Quote for Translation Work",
              "website-translation.html" : "Website Translation",
              'blog-translation.html' : "WordPress Translation",
              'drupal-translation.html' : 'Drupal Translation',
              'free-trial-translation.html' : "Free Trial Translation",
              "client_overview.html" : "Overview",
              "client_benefits.html" : "Benefits",
              "check_by_upload.html" : "Quote for Website Translation",
              "tour1.html" : "Tour, Step1",
              "tour2.html" : "Tour, Step2",
              "tour3.html" : "Tour, Step3",
              "general-translation.html" : "All Purpose Translation",
              "instant-text-translation.html" : "Text Translation",
              "customer-support-interpretation.html" : "Customer Support Interpretation",
              "support-ticket-system.html" : "Support Ticket System",
              "software_localization.html" : "Software Localization",
              "iphone_localization.html" : "iPhone Application Localization",
              "iphone_localization_guide.html" : "iPhone Application Localization Guide",
              "help-translation.html" : "Windows Help translation",
              "sisulizer.html" : "Sisulizer translation"}
              

translated_strings = {}


translated_pages = []

extensions = { EN: '',
              DE: '_de',
              PT: '_pt',
              FR: '_fr',
              ES: '_es',
              ZU: '_zu',
              IT: '_it'}

lang_name = {EN : "English",
              DE: 'German',
              PT: 'Portuguese',
              FR: 'French',
              ES: 'Spanish',
              ZU: 'Chinese',
              IT: 'Italian'}

listtype = type([])

def url_in_tree(root,url):
    for branch in root:
        if type(branch) == listtype:
            if url_in_tree(branch,url):
                return True
        elif branch == url:
            return True
    return False

def get_tab(url):
    for tab in site:
        if tab[1] == url:
            return tab[0],True
        for branch in tab[2:]:
            if url_in_tree(branch,url):
                return tab[0],False
    return None,False

def add_to_path(root,url):
    path = []
    father = None
    for branch in root:
        if type(branch) == listtype:
            tail = add_to_path(branch,url)
            if (tail != None):
                path.append(father)
                path.extend(tail)
                return path
        elif branch == url:
            path.append(branch)
            return path
        father = branch
    return None

def get_path(url):
    if url == homepage:
        return None
    path = [homepage]
    for tab in site:
        if tab[1] == url:
            path.append(tab[1])
            return path
        for branch in tab[2:]:
            tail = add_to_path(branch,url)
            if tail != None:
                if tab[1] != homepage:
                    path.append(tab[1])
                path.extend(tail)
                return path
    return None

def scan_tree(root):
    res = []
    for branch in root:
        if type(branch) == listtype:
            res.extend(scan_tree(branch))
        else:
            res.append(branch)
    return res

def xlat(str):
    if sys.cur_lang == EN:
        return str
    if translated_strings.has_key(str):
        return translated_strings[str][sys.cur_lang]
    else:
        return str

def make_tabs():
    tabs = []
    for tab in site:
        if tab[0] != None:
            tabs.append([tab[0],tab[1]])
    return tabs
        
def make_tab_nav(tabs,tab_selected,tab_root):
    res = '<ul id="topnavigation">'
    for tab_info in tabs:
        tab = tab_info[0]
        url = tab_info[1]
        classes = []
        do_link = True
        if tab == tab_selected:
            if tab_root:
               classes.append('selectedtab')
            else:
               classes.append('selectedtab_active')
            do_link = not tab_root
        else:
            classes.append('nonselectedtab')
        if tab_info == tabs[-1]:
            classes.append('lasttab')
        res += '<li class="%s">'%string.join(classes,' ')
        if do_link:
            res += '<a href="%s">%s</a>'%(url,xlat(tab))
        else:
            res += xlat(tab)
        res += '</li>'
    res = res + '</ul>'
    return res

def make_trail_nav(trail):
    if len(trail) < 2:
        return ""
    res = '<div id="trail_nav">'
    for link_idx in range(len(trail)):
        link = trail[link_idx]
        if link == homepage:
            page_name = 'Home'
        else:
            page_name = page_names[link]
        
        if (link_idx < (len(trail)-1)):
            res = res + '<a href="%s">'%link
        res = res + xlat(page_name)
        if (link_idx < (len(trail)-1)):
            res = res + '</a>&nbsp;&gt;&nbsp;'
    res = res + '</div>'
    return res

def sitemap_url(lang,url):
    return '<a href="%s%s">%s</a>'%(folders[lang],url,lang_name[lang])

def make_sitemap():
    res = ''
    for tab in site:
        if tab[1] != "sitemap.html":
            if tab[0] != None:
                tabname = tab[0]
            else:
                tabname = "Resources"
            if translated_pages.count(tab[1]):
                links = ''
                for lang in range(num_languages):
                    links = links + sitemap_url(lang,tab[1]) + '&nbsp;'
                res = res + '<h2>%s&nbsp;&nbsp;&nbsp;(%s)</h2>\n'%(tabname,links)
            else:
                res = res + '<h2><a href="%s">%s</a></h2>\n'%(tab[1],tabname)
            for branch in tab[2:]:
                res = res + '<p class="Text-standard">'+map_pages(0,branch)+'</p>'
    return res

def map_pages(level,root):
    res = ''
    localroot = False
    if len(root) == 2:
        if type(root[1]) == listtype:
            localroot = True
    for branch in root:
        if type(branch) == listtype:
            res = res + map_pages(level+1,branch)
        else:
            if localroot:
                res = res + '</p><h%d>'%(level+3)
            spacer = '&nbsp;'
            for idx in range(level+1):
                spacer = spacer + '--'
            if translated_pages.count(branch):
                links = ''
                for lang in range(num_languages):
                    links = links + sitemap_url(lang,branch) + '&nbsp;'
                res = res + spacer + '&nbsp;%s&nbsp;&nbsp;&nbsp;(%s)<br>\n'%(page_names[branch],links)
            else:
                res = res + spacer + '&nbsp;<a href="%s">%s</a><br>\n'%(branch,page_names[branch])
            if localroot:
                res = res + '</h%d><p class="Text-standard">'%(level+3)

    return res

def replace_section(txt, begin_str,end_str,new_str):
    begin_pos = string.find(txt,begin_str)
    end_pos = string.find(txt,end_str)
    # if not found, just return the original text
    if (begin_pos < 0) or (end_pos < 0):
        return txt
    new_txt = txt[:begin_pos+len(begin_str)]+new_str+txt[end_pos:]
    return new_txt

def insert_before(txt, before_str, new_str):
    before_pos = string.find(txt,before_str)
    # if not found, just return the original text
    if (before_pos < 0):
        return txt
    new_txt = txt[:before_pos]+new_str+txt[before_pos:]
    return new_txt
    
def get_lang_url(fname, ext):
    ext_pos = string.find(fname,'.')
    bname = fname[:ext_pos]
    html_ext = fname[ext_pos:]
    return '%s%s%s'%(bname, ext, html_ext)
    
# main program

footer_text = '<div id="bottom"><center><br />&copy; 2009. OnTheGoSystems Inc. | All Rights Reserved</center></div>'
top_bar = ('<div id="topbar"><a href="login/">Login</a> &nbsp;-&nbsp; <a href="about.html">About us</a> &nbsp;-&nbsp; <a href="http://www.icanlocalize.com/web_dialogs/new?language_id=1&amp;store=4">Contact</a> &nbsp;-&nbsp; <a href="/newsletters"><img border="0" align="top" src="/assets/book.png" width="16" height="16" alt="Newsletter" /></a> <a href="/newsletters">Newsletter</a> &nbsp;-&nbsp; <a href="/tools"><img border="0" align="top" src="/assets/tools.png" width="16" height="16" alt="Tools" /></a> <a href="/tools">Free Tools</a> &nbsp;-&nbsp; <a href="http://blog-en.icanlocalize.com/?feed=rss2"><img border="0" align="top" src="/assets/rss.png" width="16" height="16" alt="RSS feed" /></a> <a href="http://blog-en.icanlocalize.com">Blog</a></div>\n'+
           '<img src="/assets/web_logo_large.png" width="317" height="91" alt="ICanLocalize" class="imageBorder" />')

analytics = """<script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(decodeURIComponent("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
var pageTracker = _gat._getTracker("UA-564905-4");
pageTracker._initData();
pageTracker._trackPageview();
</script>"""


# replacement strings
top_bar_begin = "<!-- top bar -->"
top_bar_end = "<!-- /top bar -->"
top_navigation_begin = "<!-- top navigation -->"
top_navigation_end = "<!-- /top navigation -->"
footer_begin = "<!-- footer -->"
footer_end = "<!-- /footer -->"
trail_navigation_begin = "<!-- trail_navigation -->"
trail_navigation_end = "<!-- /trail_navigation -->"
analytics_begin = "<!-- analytics -->"
analytics_end = "<!-- /analytics -->"

written_files = []

# step 1) create a list of all files to scan

# setup the tabs list (from the site tree)
tabs = make_tabs()

# make a flat list of URLs (from the site tree)
urls = []
for tab in site:
    urls.append(tab[1])
    for branch in tab[2:]:
        urls.extend(scan_tree(branch))

# list of all output files (to be tar-ed)
output_files = []

for lang in range(num_languages):

    print "\n---- Doing %s ----\n"%lang_name[lang]
    sys.cur_lang = lang
    ext = extensions[lang]

    #de_idx = 0
    #de_link_path_idx = 0
    #de_link_txt = ['Passbild','Passbilder','Passbild Gr��e','Passbilder drucken']
    #de_link_path = ['','passport_photo.htm','passport_photo_specifications.htm','pp_download.htm','download.htm','buy.htm']

    # read each source file and do fixes
    for url in urls:
        if (lang == EN) or translated_pages.count(url):
            lang_url = get_lang_url(url, ext)
            if os.path.exists(lang_url):
                print "Processing %s"%lang_url
                tab,tab_is_root = get_tab(url)
                trail = get_path(url)
                #print url,get_tab(url),get_path(url)

                #print make_tab_nav(tab,tab_is_root)
                #if trail != None:
                #    print make_trail_nav(trail)

                #print make_left_nav(url)

                # read the original file
                f = open(lang_url,"r")
                txt = f.read()
                f.close()

                txt = replace_section(txt,top_bar_begin,top_bar_end,top_bar)
                txt = replace_section(txt,top_navigation_begin,top_navigation_end,make_tab_nav(tabs,tab,tab_is_root))
                txt = replace_section(txt,footer_begin,footer_end,footer_text)
                txt = replace_section(txt,analytics_begin, '</body>', analytics)
                #txt = replace_section(txt,sitemap_begin,sitemap_end,make_sitemap(article_files))

                if trail != None:
                    txt = replace_section(txt,trail_navigation_begin,trail_navigation_end,make_trail_nav(trail))
                    
                # remember this file
                written_files.append(lang_url)
                
                fname_out = "output/%s"%lang_url
                #print "would write to: %s"%fname_out
                f = open(fname_out,"w")
                f.write(txt)
                f.close()
                output_files.append(lang_url)
            else:
                print "Cannot find %s"%lang_url
        else:
            pass
            #print "%s in not translated"%url
            #print translated_pages

sm = sitemap_gen.sitemap_gen('icanlocalize.sitemap')
sm_name = 'icanlocalize_sitemap.xml'
for lang in range(num_languages):
    lang_ext = extensions[lang]
    for fname in written_files:
        lang_fname = get_lang_url(fname, lang_ext)
        print "checking %s -> %s"%(fname, lang_fname)
        if os.path.exists(lang_fname):
            f = open(lang_fname,'rb')
            txt = f.read()
            f.close()
            sm.update_file(lang_fname, txt)
        else:
            print "---> missing: %s"%lang_fname
sm.write_site_map(sm_name, 'http://www.icanlocalize.com')
sm.close()
