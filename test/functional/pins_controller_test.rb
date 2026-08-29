# frozen_string_literal: true

require_relative '../test_helper'

class PinsControllerTest < Redmine::ControllerTest
  fixtures :pins, :users, :issues, :projects, :members, :member_roles, :roles,
           :trackers, :issue_statuses, :enumerations, :enabled_modules,
           :wikis, :wiki_pages, :wiki_contents, :versions

  setup do
    @request.session[:user_id] = 2
  end

  test 'routes destroy only through the target identity collection endpoint' do
    assert_routing({method: :delete, path: '/pins'},
                   {controller: 'pins', action: 'destroy'})
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/pins/1', method: :delete)
    end
  end

  test 'create pins a visible issue with a javascript response and is idempotent' do
    Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).delete_all

    assert_difference 'Pin.count', 1 do
      post :create, params: {pinnable_type: 'Issue', pinnable_id: 1}, xhr: true
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_no_difference 'Pin.count' do
      post :create, params: {pinnable_type: 'Issue', pinnable_id: 1}, xhr: true
    end
    assert_response :success
    assert_equal 1, Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).count
  end

  test 'create redirects HTML back to a safe referring page' do
    Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    post :create, params: {pinnable_type: 'Issue', pinnable_id: 1}

    assert_redirected_to issue_url(1)
    assert_equal 1, Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).count
  end

  test 'create accepts each allowlisted target type' do
    targets = [Issue.find(1), WikiPage.find(1), Version.find(1)]
    targets.each do |target|
      type = target.class.base_class.name
      Pin.where(user_id: 2, pinnable_type: type, pinnable_id: target.id).delete_all

      assert_difference 'Pin.count', 1 do
        post :create, params: {pinnable_type: type, pinnable_id: target.id}, xhr: true
      end
      assert_response :success
    end
  end

  test 'create redirects HTML to pins when the referring page is external' do
    Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).delete_all
    @request.env['HTTP_REFERER'] = 'https://attacker.example/path'

    post :create, params: {pinnable_type: 'Issue', pinnable_id: 1}

    assert_redirected_to pins_url
  end

  test 'create rejects unsupported types' do
    assert_no_difference 'Pin.count' do
      post :create, params: {pinnable_type: 'Project', pinnable_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  test 'create rejects a missing supported target' do
    assert_no_difference 'Pin.count' do
      post :create, params: {pinnable_type: 'Issue', pinnable_id: 999_999}, xhr: true
    end
    assert_response :not_found
  end

  test 'create rejects an invisible target' do
    Issue.any_instance.stubs(:visible?).with(User.find(2)).returns(false)

    assert_no_difference 'Pin.count' do
      post :create, params: {pinnable_type: 'Issue', pinnable_id: 1}, xhr: true
    end
    assert_response :forbidden
  end

  test 'create normalizes a unique constraint race to success' do
    Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).delete_all
    Pin.create!(user_id: 2, pinnable_type: Issue.name, pinnable_id: 1)
    ActiveRecord::Associations::CollectionProxy.any_instance
      .stubs(:create!)
      .raises(ActiveRecord::RecordNotUnique)

    assert_no_difference 'Pin.count' do
      post :create, params: {pinnable_type: 'Issue', pinnable_id: 1}, xhr: true
    end

    assert_response :success
    assert_equal 1, Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).count
  end

  test 'destroy removes only the current users pin by target identity and is idempotent' do
    Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 2).delete_all
    Pin.create!(user_id: 2, pinnable_type: Issue.name, pinnable_id: 2)

    assert_difference 'Pin.count', -1 do
      delete :destroy, params: {pinnable_type: 'Issue', pinnable_id: 2}, xhr: true
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_no_difference 'Pin.count' do
      delete :destroy, params: {pinnable_type: 'Issue', pinnable_id: 2}, xhr: true
    end
    assert_response :success
    assert_equal 0, Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 2).count
  end

  test 'destroy does not reveal or remove another users pin' do
    Pin.where(pinnable_type: 'Issue', pinnable_id: 2).delete_all
    other_pin = Pin.create!(user_id: 3, pinnable_type: Issue.name, pinnable_id: 2)

    assert_no_difference 'Pin.count' do
      delete :destroy, params: {pinnable_type: 'Issue', pinnable_id: 2}, xhr: true
    end

    assert_response :success
    assert Pin.exists?(other_pin.id)
  end

  test 'destroy rejects unsupported types without changing pins' do
    assert_no_difference 'Pin.count' do
      delete :destroy, params: {pinnable_type: 'Project', pinnable_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  test 'destroy redirects HTML back and succeeds when no own pin exists' do
    Pin.where(user_id: 2, pinnable_type: 'Issue', pinnable_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    assert_no_difference 'Pin.count' do
      delete :destroy, params: {pinnable_type: 'Issue', pinnable_id: 1}
    end

    assert_redirected_to issue_url(1)
  end

  test 'login is required for write actions' do
    @request.session[:user_id] = nil

    post :create, params: {pinnable_type: 'Issue', pinnable_id: 1}
    assert_redirected_to signin_url(back_url: pins_url)

    delete :destroy, params: {pinnable_type: 'Issue', pinnable_id: 1}
    assert_redirected_to signin_url(back_url: pins_url)
  end
end
