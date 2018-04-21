ActionMailer::Base.class_eval do
  include EmailLogger
end
