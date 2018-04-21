xml.instruct! :xml, :version=>"1.0" 
xml.rss(:version=>"2.0", "xmlns:atom"=>"http://www.w3.org/2005/Atom"){
  xml.channel{
    xml.title("ICanLocalize Newsletter")
    xml.link(url_for(:only_path=>false, :action=>:index))
    xml.description("Insider tips on how to run a multilingual business")
    xml.language('en-us')
      for newsletter in @newsletters
        xml.item do
          xml.title(newsletter.subject)
          xml.description(newsletter.body_markup(false))      
          xml.author(NEWSLETTER_SENDER)               
          xml.pubDate(newsletter.chgtime.strftime("%a, %d %b %Y %H:%M:%S %z"))
          xml.link(url_for(:only_path=>false, :action=>:show, :id=>newsletter.id))
          xml.guid(url_for(:only_path=>false, :action=>:show, :id=>newsletter.id))
		  
        end
      end
  }
}
