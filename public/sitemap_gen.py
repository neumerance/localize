import md5, pickle, time, urlparse, os
from xml.etree.ElementTree import Element, ElementTree, parse, SubElement

SIGNATURE, LAST_MOD = range(2)

class sitemap_gen:
    def __init__(self, settings):
        self.loaded_setting = settings
        self.file_history = {}
        
        if os.path.exists(settings):
            f = open(settings,'rb')
            try:
                self.file_history = pickle.load(f)
            except:
                pass
            f.close()

    def update_file(self, fname, contents):
        new_sig = md5.new(contents).hexdigest()
        if not(self.file_history.has_key(fname) and (self.file_history[fname][SIGNATURE] == new_sig)):
            self.file_history[fname] = { SIGNATURE: None, LAST_MOD: time.time() }

    def write_site_map(self, map_name, domain):
        f = open(map_name, 'wt')
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
        cnt = 0
        for fname,entry in self.file_history.items():
            lt = time.strftime('%Y-%m-%d',time.localtime(entry[LAST_MOD]))
            f.write('  <url>\n')
            f.write('    <loc>%s</loc>\n'%urlparse.urljoin(domain, fname))
            f.write('    <lastmod>%s</lastmod>\n'%lt)
            f.write('  </url>\n')
            cnt += 1
        f.write('</urlset>\n')
        print "\n==== saving sitemap: %s with %d entries ====\n\n"%(map_name,cnt)
        f.close()

    def close(self):
        f = open(self.loaded_setting,'wb')
        pickle.dump(self.file_history,f)
        f.close()

    
    
