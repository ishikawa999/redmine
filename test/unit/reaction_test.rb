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

class ReactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:users_002)
    @issue = issues(:issues_001)
    @journal = journals(:journals_001)
    @message = messages(:messages_001)
    @news = news(:news_001)
    @comment = comments(:comments_001)
  end

  test 'create reaction for issue' do
    reaction = Reaction.new(reactable: @issue, user: @user)
    assert reaction.save
    assert_equal @issue, reaction.reactable
    assert_equal @user, reaction.user
  end

  test 'create reaction for journal' do
    reaction = Reaction.new(reactable: @journal, user: @user)
    assert reaction.save
    assert_equal @journal, reaction.reactable
    assert_equal @user, reaction.user
  end

  test 'create reaction for message' do
    reaction = Reaction.new(reactable: @message, user: @user)
    assert reaction.save
    assert_equal @message, reaction.reactable
    assert_equal @user, reaction.user
  end

  test 'create reaction for news' do
    reaction = Reaction.new(reactable: @news, user: @user)
    assert reaction.save
    assert_equal @news, reaction.reactable
    assert_equal @user, reaction.user
  end

  test 'create reaction for comment' do
    reaction = Reaction.new(reactable: @comment, user: @user)
    assert reaction.save
    assert_equal @comment, reaction.reactable
    assert_equal @user, reaction.user
  end

  test 'controller handles duplicate reactions' do
    # This test simulates how the controller handles duplicate reactions
    # First create a reaction
    reaction1 = Reaction.create(reactable: @issue, user: @user)
    assert reaction1.persisted?

    # Simulate controller behavior with find_or_initialize_by
    reaction2 = @issue.reactions.find_or_initialize_by(user: @user)

    # Should find the existing reaction and not create a new one
    assert reaction2.persisted?
    assert_equal reaction1.id, reaction2.id

    # Confirm only one reaction exists
    assert_equal 1, @issue.reactions.count
  end

  test 'different users can react to the same reactable' do
    user1 = users(:users_002)
    user2 = users(:users_003)

    reaction1 = Reaction.new(reactable: @issue, user: user1)
    assert reaction1.save

    reaction2 = Reaction.new(reactable: @issue, user: user2)
    assert reaction2.save

    assert_equal 2, @issue.reactions.count
  end

  test 'destroying a reactable destroys associated reactions' do
    # Create a reaction
    reaction = Reaction.new(reactable: @issue, user: @user)
    assert reaction.save
    reaction_id = reaction.id

    # Destroy the reactable
    @issue.destroy

    # Check that the reaction is also destroyed
    assert_nil Reaction.find_by(id: reaction_id)
  end

  test 'scope: by' do
    user1 = users(:users_002)
    user2 = users(:users_003)

    reaction1 = Reaction.create(reactable: @issue, user: user1)
    reaction2 = Reaction.create(reactable: @journal, user: user1)
    reaction3 = Reaction.create(reactable: @issue, user: user2)

    user1_reactions = Reaction.by(user1)
    assert_equal 2, user1_reactions.count
    assert_include reaction1, user1_reactions
    assert_include reaction2, user1_reactions
    assert_not_include reaction3, user1_reactions
  end
end
