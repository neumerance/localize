module ValidateCmsAccess
  def validate_cms_access(parameters, platform_kind, master_side, pickup_type, _website)
    if platform_kind == WEBSITE_WORDPRESS
      _('Not supported any more')
    elsif platform_kind == WEBSITE_DRUPAL
      if (master_side == true) && (pickup_type == PICKUP_BY_RPC_POST)
        begin
          uri = URI.parse(parameters[:url])
          host = uri.host
        rescue
          uri = nil
          host = nil
        end

        if host.blank?
          return _('Bad URL - must begin with http:// or https:// and contain a valid Internet address')
        end

        path = uri.path
        path += '/' if path[-1..-1] != '/'
        path += 'xmlrpc.php'
        server = XMLRPC::Client.new(host, path, 80)
      end

      nil
    else
      _('CMS type not supported yet')
    end
  end
end
