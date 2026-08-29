# frozen_string_literal: true

require_relative '../test_helper'

class PinsControllerTest < Redmine::ControllerTest
  fixtures :pins, :users, :issues, :projects, :members, :member_roles, :roles,
           :trackers, :issue_statuses, :enumerations, :enabled_modules,
           :wikis, :wiki_pages, :wiki_contents, :versions

  setup do
    @request.session[:user_id] = 2
  end

  test 'routes index and preview through separate read endpoints' do
    assert_routing({method: :get, path: '/pins'},
                   {controller: 'pins', action: 'index'})
    assert_routing({method: :get, path: '/pins/preview'},
                   {controller: 'pins', action: 'preview'})
  end

  test 'login is required for read actions' do
    @request.session[:user_id] = nil

    get :index
    assert_redirected_to signin_url(back_url: pins_url)

    get :preview
    assert_redirected_to signin_url(back_url: pins_url)
  end

  test 'index assigns all pins returned by the visible reader' do
    visible_pins = [pins(:issue_pin), pins(:wiki_page_pin), pins(:version_pin)]
    Pin::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(visible_pins)
    @controller.stubs(:default_render)

    get :index

    assert_response :success
    assert_equal visible_pins, @controller.instance_variable_get(:@pins)
  end

  test 'index assigns an empty collection when no pin is visible' do
    Pin::VisibleReader.any_instance.expects(:call).with(limit: nil).returns([])

    get :index

    assert_response :success
    assert_empty @controller.instance_variable_get(:@pins)
  end

  test 'preview renders the localized empty state in English and Japanese' do
    Pin::VisibleReader.any_instance.expects(:call).with(limit: 5).twice.returns([])

    [:en, :ja].each do |locale|
      I18n.with_locale(locale) do
        get :preview

        assert_response :success
        assert_select 'p.nodata', text: I18n.t(:label_no_pinned_items)
      end
    end
  end

  test 'index renders direct escaped links and current project for all target types' do
    pins = [pins(:issue_pin), pins(:wiki_page_pin), pins(:version_pin)]
    pins.first.pinnable.subject = '<script>issue</script>'
    Pin::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(pins)

    get :index

    assert_response :success
    assert_select 'table.pinned-items tbody tr', count: 3
    assert_select "a[href='#{issue_path(pins[0].pinnable)}']", text: /<script>issue<\/script>/
    assert_select "a[href='#{project_wiki_page_path(pins[1].pinnable.project, pins[1].pinnable.title)}']"
    assert_select "a[href='#{version_path(pins[2].pinnable)}']"
    assert_not_includes response.body, '<script>issue</script>'
    pins.each do |pin|
      assert_select "a[href='#{project_path(pin.pinnable.project)}']", text: pin.pinnable.project.name
    end
  end

  test 'preview renders direct escaped links for all target types' do
    pins = [pins(:issue_pin), pins(:wiki_page_pin), pins(:version_pin)]
    pins[1].pinnable.title = '<script>wiki</script>'
    Pin::VisibleReader.any_instance.expects(:call).with(limit: 5).returns(pins)

    get :preview

    assert_response :success
    assert_select 'ul.pin-preview-items li.pin-preview-item', count: 3
    assert_select "a[href='#{issue_path(pins[0].pinnable)}']"
    assert_select "a[href='#{project_wiki_page_path(pins[1].pinnable.project, pins[1].pinnable.title)}']"
    assert_select "a[href='#{version_path(pins[2].pinnable)}']"
    assert_not_includes response.body, '<script>wiki</script>'
  end

  test 'index excludes invisible and orphaned pins without deleting them' do
    issue_pin = pins(:issue_pin)
    orphaned_pin = pins(:wiki_page_pin)
    Issue.any_instance.stubs(:visible?).with(User.find(2)).returns(false)
    orphaned_pin.update_columns(pinnable_id: 999_999)
    @controller.stubs(:default_render)

    assert_no_difference 'Pin.count' do
      get :index
    end

    assert_response :success
    assert_equal [pins(:version_pin)], @controller.instance_variable_get(:@pins)
    assert Pin.exists?(issue_pin.id)
    assert Pin.exists?(orphaned_pin.id)
  end

  test 'preview assigns at most five pins in reader order and returns an html fragment' do
    ordered_pins = [pins(:issue_pin), pins(:wiki_page_pin), pins(:version_pin)]
    Pin::VisibleReader.any_instance.expects(:call).with(limit: 5).returns(ordered_pins)

    get :preview

    assert_response :success
    assert_equal 'text/html', response.media_type
    assert_equal ordered_pins, @controller.instance_variable_get(:@pins)
    assert_not response.body.include?('<html')
    assert_select 'ul.pin-preview-items' do
      assert_select 'li.pin-preview-item', count: 3
    end
    rendered_items = css_select('li.pin-preview-item')
    rendered_ids = rendered_items.map {|element| element['data-pin-id'].to_i}
    assert_equal ordered_pins.map(&:id), rendered_ids
    assert_equal ordered_pins.map {|pin| @controller.helpers.pin_label(pin.pinnable)},
                 rendered_items.map {|item| item.at_css('a').text}
  end

  test 'a preview reader failure is isolated from the full page endpoint' do
    Pin::VisibleReader.any_instance.stubs(:call).with(limit: 5).raises('preview failed')
    Pin::VisibleReader.any_instance.stubs(:call).with(limit: nil).returns([])

    assert_raises(RuntimeError) { get :preview }

    get :index
    assert_response :success
    assert_empty @controller.instance_variable_get(:@pins)
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
    assert_includes response.body, 'pin-toggle-issue-1'
    assert_includes response.body, "pin-preview:invalidate"
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
    assert_includes response.body, 'pin-toggle-issue-2'
    assert_includes response.body, "pin-preview:invalidate"
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
