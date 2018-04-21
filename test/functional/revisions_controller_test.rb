require File.dirname(__FILE__) + '/../test_helper'
require 'revisions_controller'
require 'rexml/document'
require 'stringio'

# Re-raise errors caught by the controller.
class RevisionsController
  def rescue_action(e)
    raise e
  end
end

class RevisionsControllerTest < ActionController::TestCase
  fixtures :projects
  fixtures :revisions

  # Replace this with your real tests.
  skip def test_truth; end
end
