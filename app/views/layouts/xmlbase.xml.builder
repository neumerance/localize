xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
xml.info do
  xml.status(@status, :err_code=>@err_code || 0)
  xml.api_version(API_VERSION)
  xml.timestamp(:time=>Time.now().to_i, :gmt_offset=>Time.now().gmt_offset)
  xml << yield
end
