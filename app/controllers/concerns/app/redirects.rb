module App
  module Redirects
    def redirect_after_login(status)
      go_to = get_prev_url(1)
      if @user
        if go_to && session[:go_to_last_url] && !cms_url?(go_to)
          session[:go_to_last_url] = nil
          redirect_to(go_to)
        elsif (@user[:type] == 'Translator') && (@user.todos[0] > 0)
          redirect_to controller: :users, action: :my_profile
        elsif @user[:type] == 'Client'
          if @user.projects.empty? && @user.web_supports.empty? &&
             @user.web_messages.empty? && @user.websites.empty? &&
             @user.text_resources.empty?
            redirect_to controller: :client, action: :getting_started
          elsif @user.source && @user.source.index('affiliate')
            redirect_to controller: :my, action: :index
          else
            redirect_to client_index_path
          end
        elsif @user[:type] == 'Alias'
          redirect_to controller: :client, action: :index
        elsif @user[:type] == 'Translator'
          redirect_to controller: :translator
        elsif @user[:type] == 'Partner'
          redirect_to controller: :partner
        elsif @user.has_supporter_privileges?
          redirect_to controller: :supporter
        end
      else
        flash[:notice] = status
        redirect_to controller: :login, action: :index
      end
    end

    def get_prev_url(level)
      begin
        prev_url = session[:last_url][-level]
      rescue
        prev_url = nil
      end
      prev_url
    end
    private :get_prev_url

    def cms_url?(url)
      url && (url.index('wid=') || url.index('session=') || url.index('lc=') || url.index('accesskey='))
    end
    private :cms_url?
  end
end
