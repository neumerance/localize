require File.dirname(__FILE__) + '/../test_helper'

class ProjectTest < ActiveSupport::TestCase
  fixtures :projects

  # verify that the project cannot be created without a name
  def test_no_name
    project = Project.new
    assert !project.valid?
    assert project.errors.key?(:name)
  end

  def test_valid_project
    project = Project.new(name: 'testProj')
    assert project.valid?
  end
end
