# warning: run at your own risk

require 'open-uri'

Website.where(cms_kind: CMS_KIND_DRUPAL).each do |website|
  begin
     open(website.url + '/wp-admin').read
     website.update_attribute :cms_kind, CMS_KIND_WORDPRESS
   rescue
     # It seems to be drupal. Let's keep this one with his cms_kind
   end
end
