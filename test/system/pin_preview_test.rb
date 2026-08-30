# frozen_string_literal: true

require_relative '../application_system_test_case'

class PinPreviewTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1024, 900)
    log_user 'jsmith', 'jsmith'
    visit '/projects/ecookbook'
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

  private

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
