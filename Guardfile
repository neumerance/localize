# A sample Guardfile
# More info at https://github.com/guard/guard#readme

notification :libnotify, timeout: 5, transient: true, append: false, urgency: :critical

guard :test do
  watch(%r{^lib/(.+)\.rb$}) { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test/.+_test\.rb$})
  watch(%r{^test/.+\.rb$})
  watch('test/test_helper.rb') { 'test' }
  notification :libnotify, timeout: 5, transient: true, append: false, urgency: :critical

  # Rails example
  watch(%r{^app/models/(.+)\.rb$})                   { |m| "test/unit/#{m[1]}_test.rb" }
  watch(%r{^app/controllers/(.+)\.rb$})              { |m| "test/functional/#{m[1]}_test.rb" }
  watch(%r{^app/views/.+\.rb$})                      { 'test/integration' }
  watch('app/controllers/application_controller.rb') { ['test/functional', 'test/integration'] }
end

guard 'brakeman', run_on_start: true, output_files: %w(brakeman.html), min_confidence: 3 do
  watch(%r{^app/.+\.(erb|haml|rhtml|rb)$})
  watch(%r{^config/.+\.rb$})
  watch(%r{^lib/.+\.rb$})
  watch('Gemfile')
end
