server '', user: 'icl', roles: %w(app db web bg)

set :repo_url, 'ssh://git_url_here/icl-upgrade/icanlocalize.git'
set :branch, 'release'
set :keep_releases, 50

namespace :deploy do
  task :update_config_file do
    on roles(:app) do
      execute "git archive --remote=ssh://git_url_here/icl-upgrade/icl-secrets.git HEAD production/application.yml | tar -xO > #{deploy_to}/shared/config/application.yml"
    end
  end
  task :set_cron_jobs do
    on roles(:app) do
      within release_path do
        execute "cd #{release_path}; ~/.rvm/bin/rvm 2.3.1@icanlocalize do bundle exec whenever --write-crontab"
      end
    end
  end
  task :set_symlink_to_robots do
    on roles(:app) do
      within release_path do
        execute "ln -s /home/icl/public_html/wordpress/site/robots.txt #{release_path}/public"
      end
    end
  end
end

before :deploy, 'deploy:update_config_file'
after :deploy, 'deploy:set_cron_jobs'
after :deploy, 'deploy:set_symlink_to_robots'

set :delayed_job_pools,
    'process_xliff' => 4, # four workers for processing xliffs
    'process_xliff,*' => 4, # never blocked by low_priority jobs
    'process_xliff,*,backup_upload_to_s3' => 2, # works on whatever is available
    '*,backup_upload_to_s3' => 2, # process_xliff doesn't starve the backup
    '*' => 1 # any other queue

set :delayed_job_roles, [:bg]
set :delayed_job_monitor, true
