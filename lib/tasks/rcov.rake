# this requires the RCOV gem to be installed on your system
namespace :test do
  desc 'Generate code coverage with rcov'
  task :rcov do
    rm_f 'doc/coverage/coverage.data'
    rm_f 'doc/coverage'
    mkdir 'doc/coverage'
    rcov = %(rcov --rails --aggregate doc/coverage/coverage.data --text-summary -Ilib --html -o doc/coverage test/**/*_test.rb)
    system rcov
    system 'open doc/coverage/index.html' if PLATFORM['darwin']
  end
end
