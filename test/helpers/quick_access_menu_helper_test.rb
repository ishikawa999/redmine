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

  test 'gives only the quick access node of the account menu a submenu' do
    User.current = User.find(2)

    selector = 'ul > li.quick-access-menu[data-controller="quick-access-preview"]' \
               '[data-quick-access-preview-url-value="/quick_access/preview"]'
    assert_select_in render_account_menu, selector, count: 1 do
      assert_select 'a.quick-access[href="/quick_access"]', text: 'Quick access'
      assert_select 'a.quick-access .quick-access-submenu-marker', count: 1
      assert_select '.quick-access-preview[data-quick-access-preview-target="preview"]', count: 1
    end
    assert_select_in render_account_menu, 'li.my-account[data-controller]', count: 0
  ensure
    User.current = nil
  end

  test 'places the quick access node right after my account' do
    User.current = User.find(2)

    assert_select_in render_account_menu, 'li:has(> a.my-account) + li.quick-access-menu', count: 1
  ensure
    User.current = nil
  end

  test 'does not render the quick access node for a guest' do
    User.current = User.anonymous

    assert_select_in render_account_menu, 'li.quick-access-menu', count: 0
  ensure
    User.current = nil
  end
end
