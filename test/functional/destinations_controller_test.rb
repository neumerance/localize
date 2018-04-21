require File.dirname(__FILE__) + '/../test_helper'
require 'destinations_controller'
require 'minitest/unit'

# Re-raise errors caught by the controller.
class DestinationsController
  def rescue_action(e)
    raise e
  end
end

class DestinationsControllerTest < ActionController::TestCase

  fixtures :destinations, :users, :user_sessions

  def setup
    @controller = DestinationsController.new
    @session = user_sessions(:supporter)
  end

  def test_should_get_index
    get :index, params: { session: @session.session_num }
    assert_response :success
    assert_not_nil assigns(:destinations)
  end

  def test_should_get_new
    get :new, params: { session: @session.session_num }
    assert_response :success
  end

  def test_should_create_destination
    assert_difference('Destination.count') do
      post :create, params: {
        session: @session.session_num,
        destination: { url: 'http://sample.com', language_id: 1, name: 'Home' }
      }
    end

    assert_redirected_to destination_path(assigns(:destination))
  end

  def test_should_show_destination
    get :show, params: { id: destinations(:one).id, session: @session.session_num }
    assert_response :success
  end

  def test_should_get_edit
    get :edit, params: { id: destinations(:one).id, session: @session.session_num }
    assert_response :success
  end

  def test_should_update_destination
    before = Destination.count
    destination = destinations(:one)
    put :update, params: {
      _method: 'update',
      id: destination.id,
      destination: { url: 'http://updated.com' },
      session: @session.session_num
    }

    assert_equal before, Destination.count
    assert_redirected_to destination_path(destination.id)
  end

  def test_should_destroy_destination
    destination = destinations(:one)

    assert_difference('Destination.count', -1) do
      delete :destroy, params: { id: destination.id, session: @session.session_num }
    end

    assert_redirected_to destinations_path
  end
end
