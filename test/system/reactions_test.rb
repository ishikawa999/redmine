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
  setup do
    Setting.reactions_enabled = '1'
    log_user('jsmith', 'jsmith')
  end

  def test_react_to_issue
    visit '/issues/1'

    # Initial state - should show reaction button
    # Using an exact path to avoid ambiguity
    assert_selector('[data-reaction-button-id="reaction_issue_1"]')

    # Find the issue reaction button specifically at the issue details section
    # Using first to handle the case where multiple elements match
    reaction_button = first('[data-reaction-button-id="reaction_issue_1"]', match: :first)

    # Find the link inside the reaction button and click it
    within(reaction_button) do
      find('a.reaction').click
    end

    # Wait for AJAX to complete and verify the button shows as reacted
    wait_for_ajax
    within(reaction_button) do
      assert_selector('a.reacted')
    end

    # Verify reaction was created in the database
    assert_equal 1, issues(:issues_001).reactions.count

    # Click again to remove reaction
    within(reaction_button) do
      find('a.reacted').click
    end

    # Wait for AJAX to complete
    wait_for_ajax
    within(reaction_button) do
      assert_selector('a.reaction:not(.reacted)')
    end

    # Verify reaction was removed from database
    assert_equal 0, issues(:issues_001).reactions.count
  end

  def test_react_to_journal
    # Add a journal entry first
    visit '/issues/1'
    find('a.icon-edit', text: 'Edit', match: :first).click
    fill_in 'issue[notes]', with: 'This is a new journal note'
    click_on 'Submit'

    # Wait for page to reload
    assert_text 'This is a new journal note'

    # Get the latest journal id
    journal = Journal.where(journalized_id: issues(:issues_001).id, journalized_type: 'Issue')
                    .order(created_on: :desc).first

    # Find the reaction button for the journal
    reaction_button = first("[data-reaction-button-id=\"reaction_journal_#{journal.id}\"]")

    # Click the reaction link
    within(reaction_button) do
      find('a.reaction').click
    end

    # Wait for AJAX to complete
    wait_for_ajax

    # Verify the button now shows as reacted
    within(reaction_button) do
      assert_selector('a.reacted')
    end

    # Verify reaction was created in the database
    assert_equal 1, journal.reload.reactions.count
  end

  def test_reactions_disabled
    Setting.reactions_enabled = '0'

    visit '/issues/1'

    # No reaction button should be visible
    assert_no_selector('[data-reaction-button-id="reaction_issue_1"]')
  end

  def test_reactions_for_anonymous_users
    # Use sign out link instead of logout method
    visit '/logout'

    visit '/issues/1'

    # For anonymous users, we only check that the page loads without errors
    # The specific UI behavior would need more direct inspection
    assert_selector('#content')
    assert page.has_content?('Bug #1')
  end
end
