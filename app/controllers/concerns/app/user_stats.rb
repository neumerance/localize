module App
  module UserStats
    def add_user_click(user, force = false)
      return if @user_click
      # track only what clients are doing
      if (force || user[:type] == 'Client') && (params[:format] != 'xml')
        params_list = (params.to_h.map { |k, v| "#{k}:#{v}" }).join(', ')
        params_list = params_list[0..254] if params_list.length > 255
        resource_id = params[:id] ? params[:id].to_i : nil
        @user_click = UserClick.create(
          user_id: user.id,
          controller: params[:controller],
          action: params[:action],
          resource_id: resource_id,
          params: params_list,
          url: request.url,
          method: request.request_method.to_s.downcase
        )
      end
    end
  end
end
