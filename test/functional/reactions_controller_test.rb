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

class ReactionsControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    Setting.reactions_enabled = '1'

    @issue = issues(:issues_001)
    @journal = journals(:journals_001)
    @message = messages(:messages_001)
    @news = news(:news_001)
    @news_comment = comments(:comments_001)
    @forum_comment = comments(:comments_002)

    @user = users(:users_002)
    @request.session[:user_id] = @user.id
  end

  # Test creating reactions for each supported object type
  def test_create_reaction_for_issue
    assert_difference 'Reaction.count' do
      post :create, :params => {
        :object_type => 'Issue',
        :object_id => @issue.id
      }, :xhr => true
    end

    assert_response :success
    assert_equal 1, @issue.reload.reactions.count
    assert_equal @user.id, @issue.reactions.first.user_id
  end

  def test_create_reaction_for_journal
    assert_difference 'Reaction.count' do
      post :create, :params => {
        :object_type => 'Journal',
        :object_id => @journal.id
      }, :xhr => true
    end

    assert_response :success
    assert_equal 1, @journal.reload.reactions.count
    assert_equal @user.id, @journal.reactions.first.user_id
  end

  def test_create_reaction_for_message
    assert_difference 'Reaction.count' do
      post :create, :params => {
        :object_type => 'Message',
        :object_id => @message.id
      }, :xhr => true
    end

    assert_response :success
    assert_equal 1, @message.reload.reactions.count
    assert_equal @user.id, @message.reactions.first.user_id
  end

  def test_create_reaction_for_news
    assert_difference 'Reaction.count' do
      post :create, :params => {
        :object_type => 'News',
        :object_id => @news.id
      }, :xhr => true
    end

    assert_response :success
    assert_equal 1, @news.reload.reactions.count
    assert_equal @user.id, @news.reactions.first.user_id
  end

  def test_create_reaction_for_news_comment
    assert_difference 'Reaction.count' do
      post :create, :params => {
        :object_type => 'Comment',
        :object_id => @news_comment.id
      }, :xhr => true
    end

    assert_response :success
    assert_equal 1, @news_comment.reload.reactions.count
    assert_equal @user.id, @news_comment.reactions.first.user_id
  end

  def test_create_reaction_for_forum_comment
    assert_difference 'Reaction.count' do
      post :create, :params => {
        :object_type => 'Comment',
        :object_id => @forum_comment.id
      }, :xhr => true
    end

    assert_response :success
    assert_equal 1, @forum_comment.reload.reactions.count
    assert_equal @user.id, @forum_comment.reactions.first.user_id
  end

  # Test deleting reactions
  def test_destroy_reaction
    # First create a reaction
    post :create, :params => {
      :object_type => 'Issue',
      :object_id => @issue.id
    }, :xhr => true

    reaction = @issue.reactions.first

    # Then delete it
    assert_difference 'Reaction.count', -1 do
      delete :destroy, :params => {
        :id => reaction.id,
        :object_type => 'Issue',
        :object_id => @issue.id
      }, :xhr => true
    end

    assert_response :success
    assert_equal 0, @issue.reload.reactions.count
  end

  # Test feature toggle
  def test_feature_disabled
    Setting.reactions_enabled = '0'

    post :create, :params => {
      :object_type => 'Issue',
      :object_id => @issue.id
    }, :xhr => true

    assert_response :forbidden
    assert_equal 0, @issue.reload.reactions.count
  end

  # Test permissions
  def test_anonymous_cannot_react
    @request.session[:user_id] = nil

    post :create, :params => {
      :object_type => 'Issue',
      :object_id => @issue.id
    }, :xhr => true

    assert_response :unauthorized
    assert_equal 0, @issue.reload.reactions.count
  end

  def test_cannot_react_to_invisible_object
    # Create a private project where the current user can't see issues
    project = Project.generate!(:is_public => false)
    issue = Issue.generate!(:project => project)

    post :create, :params => {
      :object_type => 'Issue',
      :object_id => issue.id
    }, :xhr => true

    assert_response :forbidden
    assert_equal 0, issue.reload.reactions.count
  end

  # Test creating the same reaction twice
  def test_cannot_react_twice
    # First reaction
    post :create, :params => {
      :object_type => 'Issue',
      :object_id => @issue.id
    }, :xhr => true

    assert_equal 1, @issue.reload.reactions.count

    # Second attempt should be ignored
    post :create, :params => {
      :object_type => 'Issue',
      :object_id => @issue.id
    }, :xhr => true

    assert_response :success
    assert_equal 1, @issue.reload.reactions.count, "User shouldn't be able to react multiple times"
  end

  # Test invalid object type
  def test_invalid_object_type
    post :create, :params => {
      :object_type => 'InvalidType',
      :object_id => 1
    }, :xhr => true

    assert_response :forbidden
  end
end
