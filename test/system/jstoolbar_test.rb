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

require_relative '../application_system_test_case'

class JsToolbarTest < ApplicationSystemTestCase

  def test_heading_menu_inserts_correct_markup_for_textile
    with_settings :text_formatting => 'textile' do
      log_user('jsmith', 'jsmith')
      visit 'issues/new'

      # Click heading button and select H1
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 1')]").click

      # Verify H1 markup is inserted
      assert_equal 'h1. ', find('#issue_description').value

      # Clear and test H2
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 2')]").click
      assert_equal 'h2. ', find('#issue_description').value

      # Clear and test H3
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 3')]").click
      assert_equal 'h3. ', find('#issue_description').value

      # Clear and test H4
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 4')]").click
      assert_equal 'h4. ', find('#issue_description').value

      # Clear and test H5
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 5')]").click
      assert_equal 'h5. ', find('#issue_description').value
    end
  end

  def test_heading_menu_inserts_correct_markup_for_common_mark
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit 'issues/new'

      # Click heading button and select H1
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 1')]").click

      # Verify H1 markup is inserted
      assert_equal '# ', find('#issue_description').value

      # Clear and test H2
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 2')]").click
      assert_equal '## ', find('#issue_description').value

      # Clear and test H3
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 3')]").click
      assert_equal '### ', find('#issue_description').value

      # Clear and test H4
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 4')]").click
      assert_equal '#### ', find('#issue_description').value

      # Clear and test H5
      fill_in 'Description', :with => ''
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 5')]").click
      assert_equal '##### ', find('#issue_description').value
    end
  end

  def test_heading_menu_removes_existing_heading_markup
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit 'issues/new'

      # Insert text with existing heading markup
      fill_in 'Description', :with => '## Existing Heading'
      find('#issue_description').click

      # Select all text and apply H1
      find('#issue_description').send_keys([:control, 'a'])
      find('button.jstb_heading').click
      page.find(:xpath, "//div[contains(text(), 'Heading 1')]").click

      # Verify old markup is removed and new is applied
      assert_equal '# Existing Heading', find('#issue_description').value
    end
  end
end
