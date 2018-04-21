xml.instruct! :xml, :version=>"1.0" 
xml.urlset("xmlns" => "http://www.google.com/schemas/sitemap/0.84") do
	@newsletters.each do |newsletter|
		xml.url do
			xml.loc(url_for(:only_path => false, :action=>:show, :id=>newsletter.id))
			xml.lastmod(w3c_date(newsletter.chgtime))
			xml.changefreq("weekly")
			xml.priority(0.8)
		end
	end
end