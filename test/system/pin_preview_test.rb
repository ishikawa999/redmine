# frozen_string_literal: true

require_relative '../application_system_test_case'

class PinPreviewTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1024, 900)
    log_user 'jsmith', 'jsmith'
    visit '/projects/ecookbook'
  end

  teardown do
    page.current_window.resize_to(1024, 900)
  end

  [:pointer, :keyboard].each do |input|
    [:loaded, :empty, :error].each do |state|
      define_method("test_#{input}_loading_transitions_to_#{state}") do
        User.find(2).pins.delete_all if state == :empty
        observe_preview_fetch(deferred: true, fail_response: state == :error)

        assert_current_path '/projects/ecookbook'
        assert_selector '#content h2', text: 'Overview'
        assert_equal 0, fetch_count
        open_preview(input)
        assert_selector '.pin-preview.is-open[data-state="loading"]', text: 'Loading pinned items…'
        assert_equal 1, fetch_count
        page.execute_script('window.releasePinPreviewFetch()')

        assert_selector ".pin-preview.is-open[data-state='#{state}']"
        case state
        when :loaded
          assert_selector '.pin-preview-item', count: 3
        when :empty
          assert_selector '.pin-preview .nodata', text: 'You have not pinned anything yet.'
        when :error
          assert_selector '.pin-preview', text: 'Could not load pinned items.'
          assert_current_path '/projects/ecookbook'
          assert_selector '#content h2', text: 'Overview'
        end

        page.send_keys(:escape)
        assert_selector '.pin-preview:not(.is-open)', visible: :all
        if input == :keyboard
          parent_link.send_keys([:shift, :tab])
        else
          find('#content').hover
        end
        open_preview(input)
        assert_selector ".pin-preview.is-open[data-state='#{state}']"
        assert_equal 1, fetch_count

        if input == :keyboard
          parent_link.send_keys(:enter)
        else
          parent_link.click
        end
        assert_current_path '/pins'
        assert_selector '#content h2', text: 'Pinned items'
      end
    end
  end

  def test_latest_five_are_ordered_and_all_target_types_navigate_directly
    user = User.find(2)
    user.pins.delete_all
    targets = [Issue.find(1), Issue.find(3), Issue.find(2), WikiPage.find(1), Version.find(1)]
    targets.unshift(Version.find(2))
    pins = targets.each_with_index.map do |target, index|
      user.pins.create!(pinnable: target, created_at: (10 - index).minutes.ago)
    end
    expected_ids = pins.last(5).reverse.map {|pin| pin.id.to_s}

    ['/versions/1', '/projects/ecookbook/wiki/CookBook_documentation', '/issues/2'].each do |path|
      visit '/projects/ecookbook'
      preview_menu.hover
      assert_selector '.pin-preview-item', count: 5
      assert_equal expected_ids, all('.pin-preview-item').map {|item| item['data-pin-id']}
      find(".pin-preview-item a[href='#{path}']").click
      assert_current_path path
      assert_no_current_path '/pins'
    end
  end

  def test_keyboard_internal_focus_escape_and_external_focus_leave
    observe_preview_fetch
    open_preview(:keyboard)
    assert_selector '.pin-preview.is-open[data-state="loaded"] .pin-preview-item', count: 3

    parent_link.send_keys(:tab)
    assert_selector '.pin-preview-item:first-child a:focus'
    assert_selector '.pin-preview.is-open'
    page.send_keys(:tab)
    assert_selector '.pin-preview-item:nth-child(2) a:focus'
    assert_selector '.pin-preview.is-open'
    page.send_keys(:escape)
    assert_selector '.pin-preview:not(.is-open)', visible: :all

    # Shift-Tab returns from the second item to the parent after the hidden preview.
    page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
    assert_selector 'a.pinned-items:focus'
    assert_selector '.pin-preview.is-open[data-state="loaded"]'
    assert_equal 1, fetch_count
    4.times { page.send_keys(:tab) }
    assert_no_selector 'li.pinned-items-menu a:focus'
    assert_selector '.pin-preview:not(.is-open)', visible: :all
  end

  def test_preview_styles_do_not_inherit_top_navigation_layout_and_colors
    preview_menu.hover
    assert_selector '.pin-preview-item', count: 3
    list = find('.pin-preview-items')
    link = find('.pin-preview-item a', match: :first)

    assert_equal 'block', list.style('display')['display']
    assert_equal 'rgba(25, 113, 194, 1)', link.style('color')['color']
    items = all('.pin-preview-item')
    assert_operator items[1].native.rect.y, :>=, items[0].native.rect.y + items[0].native.rect.height
    link.hover
    assert_selector '.pin-preview-item a:hover', style: {color: 'rgba(24, 100, 171, 1)'}
  end

  def test_keyboard_preview_links_navigate_directly_to_each_target_type
    ['/issues/2', '/projects/ecookbook/wiki/CookBook_documentation', '/versions/1'].each_with_index do |path, index|
      visit '/projects/ecookbook'
      open_preview(:keyboard)
      assert_selector '.pin-preview-item', count: 3
      (index + 1).times { page.send_keys(:tab) }
      assert_selector ".pin-preview-item a[href='#{path}']:focus"
      page.send_keys(:enter)
      assert_current_path path
      assert_no_current_path '/pins'
    end
  end

  def test_real_pin_changes_invalidate_cache_without_fetching_until_reopen
    visit '/issues/2'
    observe_preview_fetch
    preview_menu.hover
    assert_selector '.pin-preview-item', count: 3
    find('.pin-preview-item a', match: :first).hover
    assert_selector '.pin-preview.is-open'
    find('#content').hover
    assert_selector '.pin-preview:not(.is-open)', visible: :all
    preview_menu.hover
    assert_selector '.pin-preview-item', count: 3
    assert_equal 1, fetch_count

    ['Unpin', 'Pin'].each_with_index do |action, index|
      find('#content').hover
      open_contextual_actions_dropdown
      find('#pin-toggle-issue-2', match: :first, text: action).click
      assert_link(action == 'Unpin' ? 'Pin' : 'Unpin')
      assert_selector '.pin-preview[data-state="idle"]', visible: :all
      assert_equal index + 1, fetch_count
      assert_current_path '/issues/2'
      assert_equal action == 'Pin', User.find(2).pins.exists?(pinnable: Issue.find(2))

      preview_menu.hover
      assert_selector '.pin-preview.is-open[data-state="loaded"]'
      assert_selector '.pin-preview-item', count: action == 'Unpin' ? 2 : 3
      assert_equal index + 2, fetch_count
      if action == 'Pin'
        assert_selector '.pin-preview-item:first-child a[href="/issues/2"]'
      else
        assert_no_selector '.pin-preview-item a[href="/issues/2"]'
      end
      find('#content').hover
      preview_menu.hover
      assert_selector '.pin-preview.is-open[data-state="loaded"]'
      assert_equal index + 2, fetch_count
    end
  end

  def test_desktop_preview_fetches_once_reuses_cache_and_invalidates_lazily
    install_fetch_stub('<div class="pin-preview-item"><p class="preview-result">Preview result</p></div>')

    preview_menu.hover
    assert_selector '.pin-preview.is-open[data-state="loaded"] .preview-result'
    assert_equal 1, fetch_count

    find('#content').hover
    assert_selector '.pin-preview:not(.is-open)', visible: :all

    preview_menu.hover
    assert_selector '.pin-preview.is-open[data-state="loaded"] .preview-result'
    assert_equal 1, fetch_count

    page.execute_script("document.dispatchEvent(new CustomEvent('pin-preview:invalidate'))")
    assert_equal 1, fetch_count
    find('#content').hover
    preview_menu.hover
    assert_selector '.pin-preview.is-open[data-state="loaded"] .preview-result'
    assert_equal 2, fetch_count
  end

  def test_desktop_hover_loads_server_fragment_and_preview_link_navigates_to_target
    preview_menu.hover

    assert_selector '.pin-preview.is-open[data-state="loaded"] .pin-preview-item'
    target_link = find('.pin-preview-item a', match: :first, visible: :all)
    first_target_path = target_link[:href]
    page.execute_script('arguments[0].click()', target_link)

    assert_current_path URI(first_target_path).path
    assert_no_current_path '/pins'
  end

  def test_focus_escape_and_error_keep_parent_link_available
    install_fetch_stub('', ok: false)

    parent_link.send_keys(:tab)
    page.execute_script("document.querySelector('a.pinned-items').focus()")
    assert_selector '.pin-preview.is-open[data-state="error"]', text: 'Could not load pinned items.'

    page.send_keys(:escape)
    assert_selector '.pin-preview:not(.is-open)', visible: :all
    assert parent_link[:href].end_with?('/pins')
  end

  def test_loading_transitions_to_empty
    install_fetch_stub('<p class="nodata">You have not pinned anything yet.</p>', deferred: true)

    preview_menu.hover
    assert_selector '.pin-preview.is-open[data-state="loading"]', text: 'Loading pinned items…'
    page.execute_script('window.resolvePinPreviewFetch()')
    assert_selector '.pin-preview.is-open[data-state="empty"]', text: 'You have not pinned anything yet.'
  end

  def test_mobile_navigation_does_not_open_or_fetch_preview
    install_fetch_stub('<p>must not render</p>')
    page.current_window.resize_to(500, 800)
    find('.mobile-toggle-button').click

    preview_menu.hover
    page.execute_script("document.querySelector('.flyout-menu a.pinned-items').focus()")

    assert_equal 0, fetch_count
    assert_selector '.pin-preview:not(.is-open)', visible: :all
    assert parent_link[:href].end_with?('/pins')
  end

  def test_mobile_parent_click_navigates_to_list_without_preview_request
    page.current_window.resize_to(500, 800)
    find('.mobile-toggle-button').click
    page.execute_script(<<~JS)
      window.sessionStorage.setItem('pinPreviewFetchCount', '0');
      const originalFetch = window.fetch;
      window.fetch = function(...args) {
        if (String(args[0]).includes('/pins/preview')) {
          const count = Number(window.sessionStorage.getItem('pinPreviewFetchCount'));
          window.sessionStorage.setItem('pinPreviewFetchCount', String(count + 1));
        }
        return originalFetch.apply(this, args);
      };
    JS

    find('.flyout-menu a.pinned-items').click

    assert_current_path '/pins'
    assert_equal 0, page.evaluate_script("Number(window.sessionStorage.getItem('pinPreviewFetchCount'))")
  end

  private

  def open_preview(input)
    if input == :pointer
      preview_menu.hover
    else
      find('#top-menu a.my-page').send_keys(:tab)
      assert_selector 'a.pinned-items:focus'
    end
  end

  def observe_preview_fetch(deferred: false, fail_response: false)
    page.execute_script(<<~JS)
      window.pinPreviewFetchCount = 0;
      const originalFetch = window.fetch.bind(window);
      window.fetch = function(url, options) {
        if (!String(url).includes('/pins/preview')) return originalFetch(url, options);
        window.pinPreviewFetchCount += 1;
        const request = () => #{fail_response} ? Promise.resolve(new Response('', {status: 503})) : originalFetch(url, options);
        if (!#{deferred}) return request();
        return new Promise(resolve => { window.releasePinPreviewFetch = () => resolve(request()); });
      };
    JS
  end

  def preview_menu
    find('li.pinned-items-menu')
  end

  def parent_link
    find('a.pinned-items')
  end

  def install_fetch_stub(body, ok: true, deferred: false)
    page.execute_script(<<~JS)
      window.pinPreviewFetchCount = 0;
      window.fetch = function() {
        window.pinPreviewFetchCount += 1;
        const response = {
          ok: #{ok},
          text: function() { return Promise.resolve(#{body.to_json}); }
        };
        if (!#{deferred}) return Promise.resolve(response);

        return new Promise(function(resolve) {
          window.resolvePinPreviewFetch = function() { resolve(response); };
        });
      };
    JS
  end

  def fetch_count
    page.evaluate_script('window.pinPreviewFetchCount')
  end
end
