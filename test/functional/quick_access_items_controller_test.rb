# frozen_string_literal: true

require_relative '../test_helper'

class QuickAccessItemsControllerTest < Redmine::ControllerTest
  fixtures :quick_access_items, :users, :issues, :projects, :members, :member_roles, :roles,
           :trackers, :issue_statuses, :enumerations, :enabled_modules,
           :wikis, :wiki_pages, :wiki_contents, :versions

  setup do
    @request.session[:user_id] = 2
  end

  test 'routes index and preview through separate read endpoints' do
    assert_routing({method: :get, path: '/quick_access'},
                   {controller: 'quick_access_items', action: 'index'})
    assert_routing({method: :get, path: '/quick_access/preview'},
                   {controller: 'quick_access_items', action: 'preview'})
  end

  test 'login is required for read actions' do
    @request.session[:user_id] = nil

    get :index
    assert_redirected_to signin_url(back_url: quick_access_items_url)

    get :preview
    assert_redirected_to signin_url(back_url: quick_access_items_url)
  end

  test 'index assigns all quick_access_items returned by the visible reader' do
    visible_items = [quick_access_items(:issue_item), quick_access_items(:wiki_page_item), quick_access_items(:version_item)]
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(visible_items)
    @controller.stubs(:default_render)

    get :index

    assert_response :success
    assert_equal visible_items, @controller.instance_variable_get(:@quick_access_items)
  end

  test 'index lists project, type, name and status in that order' do
    item = quick_access_items(:issue_item)
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns([item])

    get :index

    assert_response :success
    assert_select 'table.quick-access thead th' do |headers|
      assert_equal [I18n.t(:label_project), I18n.t(:field_type), I18n.t(:field_name), ''],
                   headers.map {|header| header.text.strip}
    end
    assert_select 'table.quick-access tbody tr' do
      assert_select 'td.quick-access-project a', text: item.target.project.name
      assert_select 'td.quick-access-type', text: I18n.t(:label_issue)
      assert_select 'td.quick-access-name a', text: @controller.helpers.quick_access_label(item.target)
      assert_select 'td.quick-access-name .badge', count: 0
    end
  end

  test 'index assigns an empty collection when no item is visible' do
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns([])

    get :index

    assert_response :success
    assert_empty @controller.instance_variable_get(:@quick_access_items)
    assert_select 'p.nodata', text: I18n.t(:label_no_data)
  end

  test 'preview renders the localized empty state in English and Japanese' do
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT).twice.returns([])

    [:en, :ja].each do |locale|
      I18n.with_locale(locale) do
        get :preview

        assert_response :success
        assert_select 'p.nodata', text: I18n.t(:label_no_quick_access_items)
      end
    end
  end

  test 'index renders direct escaped links and current project for all target types' do
    quick_access_items = [quick_access_items(:issue_item), quick_access_items(:wiki_page_item), quick_access_items(:version_item)]
    quick_access_items.first.target.subject = '<script>issue</script>'
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: nil).returns(quick_access_items)

    get :index

    assert_response :success
    assert_select 'table.quick-access tbody tr', count: 3
    assert_select 'table.quick-access td.buttons a svg.icon-svg', count: 3
    assert_select 'table.quick-access td.buttons a', text: 'Remove from quick access', count: 3
    assert_select "a[href='#{issue_path(quick_access_items[0].target)}']", text: /<script>issue<\/script>/
    assert_select "a[href='#{project_wiki_page_path(quick_access_items[1].target.project, quick_access_items[1].target.title)}']"
    assert_select "a[href='#{version_path(quick_access_items[2].target)}']"
    assert_not_includes response.body, '<script>issue</script>'
    quick_access_items.each do |item|
      assert_select "a[href='#{project_path(item.target.project)}']", text: item.target.project.name
    end
  end

  test 'preview renders direct escaped links for all target types' do
    quick_access_items = [quick_access_items(:issue_item), quick_access_items(:wiki_page_item), quick_access_items(:version_item)]
    quick_access_items[1].target.title = '<script>wiki</script>'
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT).returns(quick_access_items)

    get :preview

    assert_response :success
    assert_select 'ul.quick-access-preview-items li.quick-access-preview-item', count: 3
    assert_select "a[href='#{issue_path(quick_access_items[0].target)}']"
    assert_select "a[href='#{project_wiki_page_path(quick_access_items[1].target.project, quick_access_items[1].target.title)}']"
    assert_select "a[href='#{version_path(quick_access_items[2].target)}']"
    assert_not_includes response.body, '<script>wiki</script>'
  end

  test 'index excludes invisible and orphaned quick_access_items without deleting them' do
    issue_item = quick_access_items(:issue_item)
    orphaned_pin = quick_access_items(:wiki_page_item)
    Issue.any_instance.stubs(:visible?).with(User.find(2)).returns(false)
    orphaned_pin.update_columns(target_id: 999_999)
    @controller.stubs(:default_render)

    assert_no_difference 'QuickAccessItem.count' do
      get :index
    end

    assert_response :success
    assert_equal [quick_access_items(:version_item)], @controller.instance_variable_get(:@quick_access_items)
    assert QuickAccessItem.exists?(issue_item.id)
    assert QuickAccessItem.exists?(orphaned_pin.id)
  end

  test 'preview assigns at most five quick_access_items in reader order and returns an html fragment' do
    ordered_items = [quick_access_items(:issue_item), quick_access_items(:wiki_page_item), quick_access_items(:version_item)]
    QuickAccessItem::VisibleReader.any_instance.expects(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT).returns(ordered_items)

    get :preview

    assert_response :success
    assert_equal 'text/html', response.media_type
    assert_equal ordered_items, @controller.instance_variable_get(:@quick_access_items)
    assert_not response.body.include?('<html')
    assert_select 'ul.quick-access-preview-items' do
      assert_select 'li.quick-access-preview-item', count: 3
      assert_select 'li:last-child.quick-access-preview-more' do
        assert_select 'a[href=?]', '/quick_access', text: I18n.t(:label_view_all_quick_access_items)
      end
    end

    # The heading says how many of the most recent items the submenu lists.
    assert_select 'p.quick-access-preview-heading',
                  text: I18n.t(:label_latest_quick_access_items, count: QuickAccessItem::PREVIEW_LIMIT)

    # A row reads as name, then project, then type, with an issue's state
    # trailing the type.
    issue_item = quick_access_items(:issue_item)
    within_row = "li.quick-access-preview-item[data-quick-access-id=?]"
    assert_select within_row, issue_item.id.to_s do
      assert_select '> a', text: @controller.helpers.quick_access_label(issue_item.target)
      assert_select '> span.quick-access-preview-project', text: issue_item.target.project.name
      assert_select '> span.quick-access-preview-type' do
        assert_select 'span.badge.badge-status-open', text: I18n.t(:label_open_issues)
      end
      assert_select '> span.quick-access-preview-type', text: /\A#{I18n.t(:label_issue)}\s/
    end
    # Only issues carry a badge; a version's state is left to the status column
    # of the list, and wiki pages have no state at all.
    {
      quick_access_items(:version_item) => I18n.t(:label_version),
      quick_access_items(:wiki_page_item) => I18n.t(:label_wiki_page)
    }.each do |other, type_label|
      assert_select within_row, other.id.to_s do
        assert_select '> span.quick-access-preview-type', text: type_label
        assert_select '> span.quick-access-preview-type .badge', count: 0
      end
    end
    rendered_items = css_select('li.quick-access-preview-item')
    rendered_ids = rendered_items.map {|element| element['data-quick-access-id'].to_i}
    assert_equal ordered_items.map(&:id), rendered_ids
    assert_equal ordered_items.map {|item| @controller.helpers.quick_access_label(item.target)},
                 rendered_items.map {|item| item.at_css('a').text}
  end

  test 'a preview reader failure is isolated from the full page endpoint' do
    QuickAccessItem::VisibleReader.any_instance.stubs(:call).with(limit: QuickAccessItem::PREVIEW_LIMIT).raises('preview failed')
    QuickAccessItem::VisibleReader.any_instance.stubs(:call).with(limit: nil).returns([])

    assert_raises(RuntimeError) { get :preview }

    get :index
    assert_response :success
    assert_empty @controller.instance_variable_get(:@quick_access_items)
    assert_select 'p.nodata', text: I18n.t(:label_no_data)
  end

  test 'routes destroy only through the target identity collection endpoint' do
    assert_routing({method: :delete, path: '/quick_access'},
                   {controller: 'quick_access_items', action: 'destroy'})
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/quick_access/1', method: :delete)
    end
  end

  test 'create quick_access_items a visible issue with a javascript response and is idempotent' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all

    assert_difference 'QuickAccessItem.count', 1 do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end
    assert_response :success
    assert_equal 1, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).count
    assert_includes response.body, 'quick-access-toggle-issue-1'
    assert_includes response.body, "quick-access-preview:invalidate"
  end

  test 'create redirects HTML back to a safe referring page' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    post :create, params: {target_type: 'Issue', target_id: 1}

    assert_redirected_to issue_url(1)
    assert_equal 1, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).count
  end

  test 'create accepts each allowlisted target type' do
    targets = [Issue.find(1), WikiPage.find(1), Version.find(1)]
    targets.each do |target|
      type = target.class.base_class.name
      QuickAccessItem.where(user_id: 2, target_type: type, target_id: target.id).delete_all

      assert_difference 'QuickAccessItem.count', 1 do
        post :create, params: {target_type: type, target_id: target.id}, xhr: true
      end
      assert_response :success
    end
  end

  test 'create redirects HTML to quick_access_items when the referring page is external' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = 'https://attacker.example/path'

    post :create, params: {target_type: 'Issue', target_id: 1}

    assert_redirected_to quick_access_items_url
  end

  test 'create rejects unsupported types' do
    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Project', target_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  test 'create rejects a missing supported target' do
    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 999_999}, xhr: true
    end
    assert_response :not_found
  end

  test 'create rejects an invisible target' do
    Issue.any_instance.stubs(:visible?).with(User.find(2)).returns(false)

    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end
    assert_response :forbidden
  end

  test 'create normalizes a unique constraint race to success' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    QuickAccessItem.create!(user_id: 2, target_type: Issue.name, target_id: 1)
    ActiveRecord::Associations::CollectionProxy.any_instance
      .stubs(:create!)
      .raises(ActiveRecord::RecordNotUnique)

    assert_no_difference 'QuickAccessItem.count' do
      post :create, params: {target_type: 'Issue', target_id: 1}, xhr: true
    end

    assert_response :success
    assert_equal 1, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).count
  end

  test 'destroy removes only the current users item by target identity and is idempotent' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 2).delete_all
    QuickAccessItem.create!(user_id: 2, target_type: Issue.name, target_id: 2)

    assert_difference 'QuickAccessItem.count', -1 do
      delete :destroy, params: {target_type: 'Issue', target_id: 2}, xhr: true
    end
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 2}, xhr: true
    end
    assert_response :success
    assert_equal 0, QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 2).count
    assert_includes response.body, 'quick-access-toggle-issue-2'
    assert_includes response.body, "quick-access-preview:invalidate"
  end

  test 'destroy does not reveal or remove another users item' do
    QuickAccessItem.where(target_type: 'Issue', target_id: 2).delete_all
    other_pin = QuickAccessItem.create!(user_id: 3, target_type: Issue.name, target_id: 2)

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 2}, xhr: true
    end

    assert_response :success
    assert QuickAccessItem.exists?(other_pin.id)
  end

  test 'destroy rejects unsupported types without changing quick_access_items' do
    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Project', target_id: 1}, xhr: true
    end
    assert_response :not_found
  end

  test 'destroy redirects HTML back and succeeds when no own item exists' do
    QuickAccessItem.where(user_id: 2, target_type: 'Issue', target_id: 1).delete_all
    @request.env['HTTP_REFERER'] = issue_url(1)

    assert_no_difference 'QuickAccessItem.count' do
      delete :destroy, params: {target_type: 'Issue', target_id: 1}
    end

    assert_redirected_to issue_url(1)
  end

  test 'login is required for write actions' do
    @request.session[:user_id] = nil

    post :create, params: {target_type: 'Issue', target_id: 1}
    assert_redirected_to signin_url(back_url: quick_access_items_url)

    delete :destroy, params: {target_type: 'Issue', target_id: 1}
    assert_redirected_to signin_url(back_url: quick_access_items_url)
  end
end
