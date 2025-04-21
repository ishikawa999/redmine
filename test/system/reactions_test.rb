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

class ReactionsSystemTest < ApplicationSystemTestCase
  def test_react_to_issue
    log_user('jsmith', 'jsmith')
    with_settings(reactions_enabled: '1') do
      visit '/issues/1'
      reaction_button = find('div.issue.details [data-reaction-button-id="reaction_issue_1"]')
      assert_reaction_add_and_remove(reaction_button, issues(:issues_001))
    end
  end

  def test_react_to_journal
    log_user('jsmith', 'jsmith')
    journal = Journal.where(journalized_id: 1, journalized_type: 'Issue').first
    with_settings(reactions_enabled: '1') do
      visit '/issues/1'
      reaction_button = find("[data-reaction-button-id=\"reaction_journal_#{journal.id}\"]")
      assert_reaction_add_and_remove(reaction_button, journal.reload)
    end
  end

  def test_react_to_forum_message
    log_user('jsmith', 'jsmith')
    reply_message = Message.find(1).last_reply
    with_settings(reactions_enabled: '1') do
      visit 'boards/1/topics/1'
      reaction_button = find("[data-reaction-button-id=\"reaction_message_#{reply_message.id}\"]")
      assert_reaction_add_and_remove(reaction_button, reply_message)
    end
  end

  def test_react_to_forum_reply
    log_user('jsmith', 'jsmith')
    with_settings(reactions_enabled: '1') do
      visit 'boards/1/topics/1'
      reaction_button = find("[data-reaction-button-id=\"reaction_message_1\"]")
      assert_reaction_add_and_remove(reaction_button, Message.find(1))
    end
  end

  def test_react_to_news
    log_user('jsmith', 'jsmith')
    with_settings(reactions_enabled: '1') do
      visit '/news/1'
      reaction_button = find("[data-reaction-button-id=\"reaction_news_1\"]")
      assert_reaction_add_and_remove(reaction_button, News.find(1))
    end
  end

  def test_react_to_comment
    log_user('jsmith', 'jsmith')
    comment = News.find(1).comments.first
    with_settings(reactions_enabled: '1') do
      visit '/news/1'
      reaction_button = find("[data-reaction-button-id=\"reaction_comment_#{comment.id}\"]")
      assert_reaction_add_and_remove(reaction_button, comment)
    end
  end

  def test_reactions_disabled
    log_user('jsmith', 'jsmith')

    with_settings(reactions_enabled: '0') do
      visit '/issues/1'
      assert_no_selector('[data-reaction-button-id="reaction_issue_1"]')
    end
  end

  def test_reaction_button_is_visible_but_not_clickable_for_not_logged_in_user
    with_settings(reactions_enabled: '1') do
      Reaction.create(reactable: Issue.find(1), user: User.first)
      visit '/issues/1'

      # visible
      reaction_button = find('div.issue.details [data-reaction-button-id="reaction_issue_1"]')
      within(reaction_button) { assert_selector('span.reaction-button[title="Redmine Admin"]') }
      assert_equal "1", reaction_button.text

      # not clickable
      within(reaction_button) { assert_no_selector('a.reaction-button') }
    end
  end

  private

  def assert_reaction_add_and_remove(reaction_button, expected_subject)
    # Add a reaction
    within(reaction_button) { find('a.reaction-button').click }
    wait_for_ajax
    find('body').hover # Hide tooltip
    within(reaction_button) { assert_selector('a.reaction-button.reacted[title="John Smith"]') }
    assert_equal "1", reaction_button.text
    assert_equal 1, expected_subject.reactions.count

    # Remove the reaction
    within(reaction_button) { find('a.reacted').click }
    wait_for_ajax
    within(reaction_button) { assert_selector('a.reaction-button:not(.reacted)') }
    assert_equal "0", reaction_button.text
    assert_equal 0, expected_subject.reactions.count
  end
end
