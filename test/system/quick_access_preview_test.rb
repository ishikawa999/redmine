# frozen_string_literal: true

require_relative '../application_system_test_case'

class QuickAccessPreviewTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1024, 900)
    log_user 'jsmith', 'jsmith'
    visit '/projects/ecookbook'
  end

  teardown do
    page.current_window.resize_to(1024, 900)
  end

  [:loaded, :empty, :error].each do |state|
    define_method("test_opening_the_account_menu_transitions_from_loading_to_#{state}") do
      User.find(2).quick_access_items.delete_all if state == :empty
      observe_preview_fetch(deferred: true, fail_response: state == :error)

      assert_current_path '/projects/ecookbook'
      assert_selector '#content h2', text: 'Overview'
      assert_equal 0, fetch_count

      open_preview
      assert_selector '.quick-access-preview[data-state="loading"]', text: 'Loading quick access items…'
      assert_equal 1, fetch_count
      page.execute_script('window.releaseQuickAccessPreviewFetch()')

      assert_selector ".quick-access-preview[data-state='#{state}']"
      case state
      when :loaded
        assert_selector '.quick-access-preview-item', count: 3
      when :empty
        assert_selector '.quick-access-preview .nodata', text: 'You have not added anything to quick access yet.'
      when :error
        assert_selector '.quick-access-preview', text: 'Could not load quick access items.'
        assert_current_path '/projects/ecookbook'
        assert_selector '#content h2', text: 'Overview'
      end

      # Reopening serves the same state without asking the server again.
      close_preview
      open_preview
      assert_selector ".quick-access-preview[data-state='#{state}']"
      assert_equal 1, fetch_count

      quick_access_link.click
      assert_current_path '/quick_access'
      assert_selector '#content h2', text: 'Quick access'
    end
  end

  def test_latest_five_are_ordered_and_all_target_types_navigate_directly
    user = User.find(2)
    user.quick_access_items.delete_all
    targets = [Issue.find(1), Issue.find(3), Issue.find(2), WikiPage.find(1), Version.find(1)]
    targets.unshift(Version.find(2))
    quick_access_items = targets.each_with_index.map do |target, index|
      user.quick_access_items.create!(target: target, created_at: (10 - index).minutes.ago)
    end
    expected_ids = quick_access_items.last(5).reverse.map {|item| item.id.to_s}

    ['/versions/1', '/projects/ecookbook/wiki/CookBook_documentation', '/issues/2'].each do |path|
      visit '/projects/ecookbook'
      open_preview
      assert_selector '.quick-access-preview-item', count: 5
      assert_equal expected_ids, all('.quick-access-preview-item').map {|item| item['data-quick-access-id']}
      find(".quick-access-preview-item a[href='#{path}']").click
      assert_current_path path
      assert_no_current_path '/quick_access'
    end
  end

  def test_submenu_opens_towards_the_leading_edge_and_keeps_its_rows_inside
    open_preview
    assert_selector '.quick-access-preview-item', count: 3

    list = find('.quick-access-preview-items')
    assert_equal 'block', list.style('display')['display']
    # The panel already carries the dropdown's submenu treatment, so the list
    # inside it must not draw a second border on top.
    assert_equal 'none', list.style('border-style')['border-style']
    assert_equal 'none', list.style('box-shadow')['box-shadow']

    panel = find('.quick-access-preview').native.rect
    link_box = quick_access_link.native.rect

    # The account menu hugs the trailing edge, so the submenu opens to its left
    # and lines up with the row it belongs to rather than dropping below it.
    assert_operator panel.x + panel.width, :<=, link_box.x + link_box.width
    assert_operator panel.y, :<=, link_box.y

    # Rows stack downwards and stay within the panel, so a hovered or focused
    # row never paints outside it.
    rows = all('.quick-access-preview-item').map {|row| row.native.rect}
    assert_operator rows[1].y, :>, rows[0].y
    rows.each do |row|
      assert_operator row.x, :>=, panel.x
      assert_operator row.x + row.width, :<=, panel.x + panel.width
    end
  end

  def test_keyboard_reaches_every_preview_link_once_the_menu_is_open
    ['/issues/2', '/projects/ecookbook/wiki/CookBook_documentation', '/versions/1'].each_with_index do |path, index|
      visit '/projects/ecookbook'
      open_preview
      assert_selector '.quick-access-preview-item', count: 3

      quick_access_link.send_keys(:tab)
      index.times { page.send_keys(:tab) }
      assert_selector ".quick-access-preview-item a[href='#{path}']:focus"
      page.send_keys(:enter)
      assert_current_path path
      assert_no_current_path '/quick_access'
    end
  end

  def test_real_changes_invalidate_the_cache_without_fetching_until_reopen
    visit '/issues/2'
    observe_preview_fetch
    open_preview
    assert_selector '.quick-access-preview-item', count: 3
    close_preview
    open_preview
    assert_selector '.quick-access-preview-item', count: 3
    assert_equal 1, fetch_count
    close_preview

    ['Remove from quick access', 'Add to quick access'].each_with_index do |action, index|
      open_contextual_actions_dropdown
      find('#quick-access-toggle-issue-2', match: :first, text: action).click
      assert_link(action == 'Remove from quick access' ? 'Add to quick access' : 'Remove from quick access')
      assert_selector '.quick-access-preview[data-state="idle"]', visible: :all
      assert_equal index + 1, fetch_count
      assert_current_path '/issues/2'
      assert_equal action == 'Add to quick access', User.find(2).quick_access_items.exists?(target: Issue.find(2))

      open_preview
      assert_selector '.quick-access-preview[data-state="loaded"]'
      assert_selector '.quick-access-preview-item', count: action == 'Remove from quick access' ? 2 : 3
      assert_equal index + 2, fetch_count
      if action == 'Add to quick access'
        assert_selector '.quick-access-preview-item:first-child a[href="/issues/2"]'
      else
        assert_no_selector '.quick-access-preview-item a[href="/issues/2"]'
      end

      close_preview
      open_preview
      assert_selector '.quick-access-preview[data-state="loaded"]'
      assert_equal index + 2, fetch_count
      close_preview
    end
  end

  def test_preview_fetches_once_reuses_cache_and_invalidates_lazily
    install_fetch_stub('<div class="quick-access-preview-item"><p class="preview-result">Preview result</p></div>')

    open_preview
    assert_selector '.quick-access-preview[data-state="loaded"] .preview-result'
    assert_equal 1, fetch_count

    close_preview
    open_preview
    assert_selector '.quick-access-preview[data-state="loaded"] .preview-result'
    assert_equal 1, fetch_count

    page.execute_script("document.dispatchEvent(new CustomEvent('quick-access-preview:invalidate'))")
    assert_equal 1, fetch_count
    close_preview
    open_preview
    assert_selector '.quick-access-preview[data-state="loaded"] .preview-result'
    assert_equal 2, fetch_count
  end

  def test_preview_link_navigates_to_the_server_rendered_target
    open_preview

    assert_selector '.quick-access-preview[data-state="loaded"] .quick-access-preview-item'
    target_link = find('.quick-access-preview-item a', match: :first, visible: :all)
    first_target_path = target_link[:href]
    page.execute_script('arguments[0].click()', target_link)

    assert_current_path URI(first_target_path).path
    assert_no_current_path '/quick_access'
  end

  def test_a_failed_fetch_keeps_the_list_link_usable
    install_fetch_stub('', ok: false)

    open_preview
    assert_selector '.quick-access-preview[data-state="error"]', text: 'Could not load quick access items.'
    assert quick_access_link[:href].end_with?('/quick_access')

    quick_access_link.click
    assert_current_path '/quick_access'
    assert_selector '#content h2', text: 'Quick access'
  end

  # On a small screen the account menu is folded into the flyout navigation,
  # which never opens a dropdown, so the link goes straight to the list.
  def test_small_screen_reaches_the_list_without_requesting_the_preview
    page.current_window.resize_to(500, 800)
    page.execute_script(<<~JS)
      window.sessionStorage.setItem('quickAccessPreviewFetchCount', '0');
      const originalFetch = window.fetch.bind(window);
      window.fetch = function(url, options) {
        if (String(url).includes('/quick_access/preview')) {
          const count = Number(window.sessionStorage.getItem('quickAccessPreviewFetchCount'));
          window.sessionStorage.setItem('quickAccessPreviewFetchCount', String(count + 1));
        }
        return originalFetch(url, options);
      };
    JS

    find('.mobile-toggle-button').click
    find('.flyout-menu a.quick-access').click

    assert_current_path '/quick_access'
    assert_selector '#content h2', text: 'Quick access'
    assert_equal 0, page.evaluate_script("Number(window.sessionStorage.getItem('quickAccessPreviewFetchCount'))")
  end

  private

  # Opens the account menu when it is closed, then hovers the quick access
  # node so its submenu opens alongside it.
  def open_preview
    unless page.has_selector?('#account .dropdown-content:not(.hidden)')
      find('#account .dropdown-trigger').click
      assert_selector '#account .dropdown-content:not(.hidden)'
    end

    find('#account li.quick-access-menu').hover
    assert_selector '.quick-access-preview.is-open'
  end

  # Closes the submenu without closing the account menu around it.
  def close_preview
    find('#account a.my-account').hover
    assert_selector '.quick-access-preview:not(.is-open)', visible: :all
  end

  def quick_access_link
    find('#account a.quick-access')
  end

  def observe_preview_fetch(deferred: false, fail_response: false)
    page.execute_script(<<~JS)
      window.quickAccessPreviewFetchCount = 0;
      const originalFetch = window.fetch.bind(window);
      window.fetch = function(url, options) {
        if (!String(url).includes('/quick_access/preview')) return originalFetch(url, options);
        window.quickAccessPreviewFetchCount += 1;
        const request = () => #{fail_response} ? Promise.resolve(new Response('', {status: 503})) : originalFetch(url, options);
        if (!#{deferred}) return request();
        return new Promise(resolve => { window.releaseQuickAccessPreviewFetch = () => resolve(request()); });
      };
    JS
  end

  def install_fetch_stub(body, ok: true, deferred: false)
    page.execute_script(<<~JS)
      window.quickAccessPreviewFetchCount = 0;
      window.fetch = function() {
        window.quickAccessPreviewFetchCount += 1;
        const response = {
          ok: #{ok},
          text: function() { return Promise.resolve(#{body.to_json}); }
        };
        if (!#{deferred}) return Promise.resolve(response);

        return new Promise(function(resolve) {
          window.resolveQuickAccessPreviewFetch = function() { resolve(response); };
        });
      };
    JS
  end

  def fetch_count
    page.evaluate_script('window.quickAccessPreviewFetchCount')
  end
end
