# server '52.202.24.216', user: 'ubuntu', roles: %w(app db web) jenkins machine
server '', user: 'icl', roles: %w(app) # stg

set :repo_url, 'git_url_here'
# set :branch, 'master'
# set :branch, 'icldev-968_import_TM_in_new_format'
# set :branch, 'icldev-1558-v2.1'
set :branch, 'icldev-2184_update_importer_for_untranslated'
set :rvm_type, :user

namespace :deploy do
  task :remove_htaccess_file do
    on roles(:app) do
      execute "rm #{release_path}/public/.htaccess"
      `echo "removed public/.htaccess file"`
    end
  end
  task :update_config_file do
    on roles(:app) do
      execute "git archive --remote=ssh://git_url_here/icl-upgrade/icl-secrets.git HEAD sandbox/application.yml | tar -xO > #{deploy_to}/shared/config/application.yml"
    end
  end
end

# before :deploy, 'deploy:update_config_file'
after :deploy, 'deploy:remove_htaccess_file'

# set :ssh_options,    keys: %w(~/.ssh/otgs_qa_env.pem),
#                      forward_agent: false,
#                      auth_methods: %w(publickey)

set :ssh_options, keys: %w(~/.ssh/id_temp_01),
                  forward_agent: false,
                  auth_methods: %w(publickey)
