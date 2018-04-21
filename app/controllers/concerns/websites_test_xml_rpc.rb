module WebsitesTestXmlRpc
  def test_xmlrpc(url, xmlrpc_path)
    if !xmlrpc_path.blank?
      begin
        uri = URI.parse(xmlrpc_path)
        host = uri.host
      rescue
        uri = nil
        host = nil
      end
      return false if host.blank?
      path = uri.path
    else
      begin
        uri = URI.parse(url)
        host = uri.host
      rescue
        uri = nil
        host = nil
      end
      return false if host.blank?
      path = uri.path
      path += '/' if path[-1..-1] != '/'
      path += 'xmlrpc.php'
    end

    # the connection can fail if the remote site is denying
    begin
      server = XMLRPC::Client.new(host, path, 80)
      server.http_header_extra = { 'User-Agent' => XMLRPC_USER_AGENT }

    rescue RuntimeError, Timeout::Error
      return false
    end

    if Rails.env != 'test'
      begin
        res = server.call('icanlocalize.test_xmlrpc')
      rescue
        res = false
      end
    else
      res = true
    end

    res
  end
end
