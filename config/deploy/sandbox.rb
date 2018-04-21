server '', user: 'ubuntu', roles: %w(app db web)

set :repo_url, 'git_url_here'
set :branch, 'master'

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

before :deploy, 'deploy:update_config_file'
after :deploy, 'deploy:remove_htaccess_file'

set :delayed_job_workers, 2

set :delayed_job_roles, [:app]
set :delayed_job_monitor, true

# set :ssh_options, keys: %w(~/.ssh/id_rsa),
#                   forward_agent: false,
#                   auth_methods: %w(publickey)
