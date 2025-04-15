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

require_relative '../../../test_helper'

class Redmine::ReactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:users_002)
    @issue = issues(:issues_001)
    @journal = journals(:journals_001)
    @message = messages(:messages_001)
    @news = news(:news_001)
    @comment = comments(:comments_001)

    Setting.reactions_enabled = '1'
  end

  test 'reactable models include Redmine::Reaction::Reactable' do
    assert Issue.included_modules.include?(Redmine::Reaction::Reactable)
    assert Journal.included_modules.include?(Redmine::Reaction::Reactable)
    assert Message.included_modules.include?(Redmine::Reaction::Reactable)
    assert News.included_modules.include?(Redmine::Reaction::Reactable)
    assert Comment.included_modules.include?(Redmine::Reaction::Reactable)
  end

  test 'reactable has many reactions' do
    assert_respond_to @issue, :reactions
    assert_respond_to @journal, :reactions
    assert_respond_to @message, :reactions
    assert_respond_to @news, :reactions
    assert_respond_to @comment, :reactions
  end

  test 'reactable has many reaction_users' do
    assert_respond_to @issue, :reaction_users
    assert_respond_to @journal, :reaction_users
    assert_respond_to @message, :reaction_users
    assert_respond_to @news, :reaction_users
    assert_respond_to @comment, :reaction_users
  end

  test 'reaction_by returns reaction for specific user' do
    # Create a reaction
    reaction = Reaction.create(reactable: @issue, user: @user)

    # Test reaction_by method
    assert_equal reaction, @issue.reaction_by(@user)
    assert_nil @issue.reaction_by(users(:users_003)) # Another user
  end

  test 'reaction_by finds reaction when reactions are preloaded' do
    # Create a reaction
    reaction = Reaction.create(reactable: @issue, user: @user)

    # Preload reactions
    issue_with_reactions = Issue.includes(:reactions).find(@issue.id)

    # Test reaction_by method with preloaded reactions
    assert_equal reaction.id, issue_with_reactions.reaction_by(@user).id
  end

  test 'with_reactions scope preloads reactions when enabled' do
    # Create a reaction
    Reaction.create(reactable: @issue, user: @user)

    # Test with_reactions scope
    issue = Issue.with_reactions.find(@issue.id)
    assert issue.association(:reactions).loaded?
    assert issue.association(:reaction_users).loaded?
  end

  test 'with_reactions scope does not preload when disabled' do
    Setting.reactions_enabled = '0'

    # Create a reaction
    Reaction.create(reactable: @issue, user: @user)

    # Test with_reactions scope when disabled
    issue = Issue.with_reactions.find(@issue.id)
    assert_not issue.association(:reactions).loaded?
    assert_not issue.association(:reaction_users).loaded?
  end
end
