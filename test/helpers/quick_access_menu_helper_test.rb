# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

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

  def test_gives_only_the_quick_access_node_of_the_account_menu_a_submenu
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

  def test_places_the_quick_access_node_right_after_my_account
    User.current = User.find(2)

    assert_select_in render_account_menu, 'li:has(> a.my-account) + li.quick-access-menu', count: 1
  ensure
    User.current = nil
  end

  def test_does_not_render_the_quick_access_node_for_a_guest
    User.current = User.anonymous

    assert_select_in render_account_menu, 'li.quick-access-menu', count: 0
  ensure
    User.current = nil
  end
end
