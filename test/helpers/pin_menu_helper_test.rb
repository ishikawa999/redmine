# frozen_string_literal: true

require_relative '../test_helper'

class PinMenuHelperTest < Redmine::HelperTest
  include Redmine::MenuManager::MenuHelper
  include PinMenuHelper

  def current_menu_item
    nil
  end

  def h(text)
    ERB::Util.html_escape(text)
  end

  test 'renders only pinned items with its preview wrapper' do
    User.current = User.find(2)

    selector = 'ul > li.pinned-items-menu[data-controller="pin-preview"][data-pin-preview-url-value="/pins/preview"]'
    assert_select_in render_top_menu, selector, count: 1 do
      assert_select 'a.pinned-items[href="/pins"]', text: 'Pinned items'
      assert_select '.pin-preview[data-pin-preview-target="preview"]', count: 1
    end
    assert_select_in render_top_menu, 'li.home[data-controller]', count: 0
  ensure
    User.current = nil
  end

  test 'does not render pinned items for a guest' do
    User.current = User.anonymous

    assert_select_in render_top_menu, 'li.pinned-items-menu', count: 0
  ensure
    User.current = nil
  end
end
