# -*- coding: UTF-8 -*-

import os, string, urllib, sys, tarfile, time

base_url = '/site/'

page_urls = {"" : "",
             
             "index.html" : "",
             "about.html" : "about-us/",
             "website-translation.html" : "services/website-translation/",
             'blog-translation.html' : "services/website-translation/wordpress-translation/",
             'drupal-translation.html' : 'services/website-translation/drupal-translation/',
             "general-translation.html" : "services/general-translation/",
             "instant-text-translation.html" : "services/text-translation/",
             "customer-support-interpretation.html" : "services/text-translation/customer-support/",
             "support-ticket-system.html" : "services/text-translation/free-support-ticket-system/",
             "software_localization.html" : "services/software-localization/",
             "iphone_localization.html" : "services/software-localization/iphone-application-localization/",
             "iphone_localization_guide.html" : "tutorials/iphone-applications-localization-guide/",
             "help-translation.html" : "services/software-localization/windows-help-file-translation/",
             "sisulizer.html" : "services/software-localization/sisulizer-projects/",
             
             "index_es.html" : "es/",
             "about_es.html" : "es/quienes-somos/",
             "website-translation_es.html" : "es/servicios/traduccion-de-sitios-web/",
             'blog-translation_es.html' : "es/servicios/traduccion-de-sitios-web/traduccion-con-wordpress/",
             'drupal-translation_es.html' : 'es/servicios/traduccion-de-sitios-web/traduccion-de-sitios-en-drupal/',
             "general-translation_es.html" : "es/servicios/traduccion-general/",
             "instant-text-translation_es.html" : "es/servicios/traduccion-de-textos/",
             "customer-support-interpretation_es.html" : "es/servicios/traduccion-de-textos/sistema-de-soporte-por-tickets-gratis/",
             "support-ticket-system_es.html" : "es/servicios/traduccion-de-textos/sistema-de-soporte-por-tickets-gratis/",
             "software_localization_es.html" : "es/servicios/localizacion-de-software/",
             "iphone_localization_es.html" : "es/servicios/localizacion-de-software/localizacion-de-aplicaciones-iphone/",
             "iphone_localization_guide_es.html" : "es/tutoriales/guia-para-la-localizacion-de-aplicaciones-iphone/",
             "help-translation_es.html" : "es/servicios/localizacion-de-software/traduccion-de-archivos-de-ayuda-de-windows/",
             "sisulizer_es.html" : "es/servicios/localizacion-de-software/proyectos-sisulizer/",
             
             "index_fr.html" : "fr/",
             "about_fr.html" : "fr/a-propos-de-nous/",
             "website-translation_fr.html" : "fr/services-2/traduction-de-site-web/",
             'blog-translation_fr.html' : "fr/services-2/traduction-de-site-web/traduction-de-wordpress/",
             'drupal-translation_fr.html' : 'fr/services-2/traduction-de-site-web/traduction-de-sites-drupal/',
             "general-translation_fr.html" : "fr/services-2/traduction-generale/",
             "instant-text-translation_fr.html" : "fr/services-2/traduction-de-texte/",
             "customer-support-interpretation_fr.html" : "fr/services-2/traduction-de-texte/traduction-de-lassistance-a-la-clientele/",
             "support-ticket-system_fr.html" : "fr/services-2/traduction-de-texte/systeme-de-ticket-dassistance-gratuit/",
             "software_localization_fr.html" : "fr/services-2/localisation-de-logiciel/",
             "iphone_localization_fr.html" : "fr/services-2/localisation-de-logiciel/localisation-dapplications-iphone/",
             "iphone_localization_guide_fr.html" : "fr/tutoriels/guide-de-localisation-pour-les-applications-iphone/",
             "help-translation_fr.html" : "fr/services-2/localisation-de-logiciel/traduction-de-fichiers-daide-windows/",
             "sisulizer_fr.html" : "fr/services-2/localisation-de-logiciel/projets-sisulizer/",
             
             "index_de.html" : "de/",
             "about_de.html" : "de/uber-uns/",
             "website-translation_de.html" : "de/leistungen/webseiten-ubersetzung/",
             'blog-translation_de.html' : "de/leistungen/webseiten-ubersetzung/wordpress-ubersetzung/",
             'drupal-translation_de.html' : 'de/leistungen/webseiten-ubersetzung/drupal-ubersetzung/',
             "general-translation_de.html" : "de/leistungen/allgemeine-ubersetzung/",
             "instant-text-translation_de.html" : "de/leistungen/textubersetzung/",
             "customer-support-interpretation_de.html" : "de/leistungen/textubersetzung/ubersetzung-der-kundenbetreuung/",
             "support-ticket-system_de.html" : "de/leistungen/textubersetzung/kostenloses-support-ticket-system/",
             "software_localization_de.html" : "de/leistungen/software-lokalisierung/",
             "iphone_localization_de.html" : "de/leistungen/software-lokalisierung/lokalisierung-von-iphone-programmen/",
             "iphone_localization_guide_de.html" : "de/tutorials-2/anleitung-zur-lokalisierung-von-iphone-programmen/",
             "help-translation_de.html" : "de/leistungen/software-lokalisierung/ubersetzung-von-windows-hilfsdateien/",
             "sisulizer_de.html" : "de/leistungen/software-lokalisierung/sisulizer-projekte/",
             
             "web-designers.html" : None,
             "get_quote.html" : None,
             'free-trial-translation.html' : None,
             "client_overview.html" : None,
             "client_benefits.html" : None,
             "check_by_upload.html" : None,
             "tour1.html" : None,
             "tour2.html" : None,
             "tour3.html" : None}
              
for k,v in page_urls.items():
    if v != None:
        target = base_url+v
        print("  Redirect 301 /%s %s")%(k,target)
