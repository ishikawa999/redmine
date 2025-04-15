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

require_relative '../../test_helper'

class ReactionsHelperTest < ActionView::TestCase
  include ReactionsHelper

  setup do
    User.current = users(:users_002)
    @issue = issues(:issues_001)
    Setting.reactions_enabled = '1'
  end

  test 'reaction_id_for generates a DOM id' do
    assert_equal "reaction_issue_1", reaction_id_for(@issue)
  end

  test 'reaction_button returns nil when feature is disabled' do
    Setting.reactions_enabled = '0'
    assert_nil reaction_button(@issue)
  end

  test 'reaction_button returns nil when object not visible' do
    # Make the issue not visible to the current user
    @issue.stubs(:visible?).returns(false)
    assert_nil reaction_button(@issue)
  end

  test 'reaction_button generates a button with correct attributes' do
    # Make sure the issue is visible to the current user
    @issue.stubs(:visible?).returns(true)
    result = reaction_button(@issue)

    # Test that it contains a span with the data attribute
    assert_match /data-reaction-button-id/, result

    # When logged in user with no reaction, should have a reaction link
    assert_match /<a.*class=".*reaction.*"/, result
  end

  test 'reaction_button for anonymous users shows static icon' do
    User.current = nil
    @issue.stubs(:visible?).returns(true)

    result = reaction_button(@issue)

    # Should contain a span rather than a link
    assert_match /<span.*class=".*reaction.*"/, result
    assert_no_match /<a/, result
  end
end
