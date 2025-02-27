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

class CopyPreContentToClipboardSystemTest < ApplicationSystemTestCase
  def test_copy_issue_pre_content_to_clipboard_if_common_mark
    log_user('jsmith', 'jsmith')
    issue = Issue.find(1)
    issue.journals.first.update(notes: "```\ntest\n```")
    visit "/issues/#{issue.id}"

    # A button appears when hovering over the <pre> tag
    find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type").hover
    find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link")

    # Copy pre content to Clipboard
    find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link").click

    # Paste the value copied to the clipboard into the textarea to get and test
    first('.icon-edit').click
    find('textarea#issue_notes').send_keys([modifier_key, 'v'])
    assert_equal find('textarea#issue_notes').value, 'test'
  end

  def test_copy_issue_code_content_to_clipboard_if_common_mark
    log_user('jsmith', 'jsmith')
    issue = Issue.find(1)
    issue.journals.first.update(notes: "```ruby\nputs \"Hello, World.\"\n```")
    visit "/issues/#{issue.id}"

    # A button appears when hovering over the <pre> tag
    find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type").hover
    find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link")

    # Copy pre content to Clipboard
    find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link").click

    # Paste the value copied to the clipboard into the textarea to get and test
    first('.icon-edit').click
    find('textarea#issue_notes').send_keys([modifier_key, 'v'])
    assert_equal find('textarea#issue_notes').value, 'puts "Hello, World."'
  end

  def test_copy_issue_pre_content_to_clipboard_if_textile
    log_user('jsmith', 'jsmith')
    issue = Issue.find(1)
    issue.journals.first.update(notes: "<pre>\ntest\n</pre>")

    with_settings text_formatting: :textile do
      visit "/issues/#{issue.id}"

      # A button appears when hovering over the <pre> tag
      find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type").hover
      find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link")

      # Copy pre content to Clipboard
      find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link").click

      # Paste the value copied to the clipboard into the textarea to get and test
      first('.icon-edit').click
      find('textarea#issue_notes').send_keys([modifier_key, 'v'])
      assert_equal find('textarea#issue_notes').value, 'test'
    end
  end

  def test_copy_issue_code_content_to_clipboard_if_textile
    log_user('jsmith', 'jsmith')
    issue = Issue.find(1)
    issue.journals.first.update(notes: "<pre><code class=\"ruby\">\nputs \"Hello, World.\"\n</code></pre>")

    with_settings text_formatting: :textile do
      visit "/issues/#{issue.id}"

      # A button appears when hovering over the <pre> tag
      find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type").hover
      find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link")

      # Copy pre content to Clipboard
      find("#journal-#{issue.journals.first.id}-notes div.pre-wrapper:first-of-type .copy-pre-content-link").click

      # Paste the value copied to the clipboard into the textarea to get and test
      first('.icon-edit').click
      find('textarea#issue_notes').send_keys([modifier_key, 'v'])
      assert_equal find('textarea#issue_notes').value, 'puts "Hello, World."'
    end
  end

  private

  def modifier_key
    modifier = osx? ? 'command' : 'control'
    modifier.to_sym
  end
end
