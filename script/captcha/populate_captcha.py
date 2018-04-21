import os, sys

f = open('migration.txt','w')

source = '../../captcha_background'
for name in os.listdir(source):
    fname = os.path.join(source, name)
    if not os.path.isdir(fname):
        print "found: %s"%fname
        f.write("\t\tCaptchaBackground.create(:fname=>'%s')\n"%name)
f.close()
