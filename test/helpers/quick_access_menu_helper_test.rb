# frozen_string_literal: true

require_relative '../test_helper'

class QuickAccessMenuHelperTest < Redmine::HelperTest
  include Redmine::MenuManager::MenuHelper
  include QuickAccessMenuHelper

  def current_menu_item
    nil
  end

  def h(text)
    ERB::Util.html_escape(text)
  end

  test 'renders only the quick access node with its preview wrapper' do
    User.current = User.find(2)

    selector = 'ul > li.quick-access-menu[data-controller="quick-access-preview"][data-quick-access-preview-url-value="/quick_access/preview"]'
    assert_select_in render_top_menu, selector, count: 1 do
      assert_select 'a.quick-access[href="/quick_access"]', text: 'Quick access'
      assert_select '.quick-access-preview[data-quick-access-preview-target="preview"]', count: 1
    end
    assert_select_in render_top_menu, 'li.home[data-controller]', count: 0
  ensure
    User.current = nil
  end

  test 'does not render the quick access node for a guest' do
    User.current = User.anonymous

    assert_select_in render_top_menu, 'li.quick-access-menu', count: 0
  ensure
    User.current = nil
  end
end
