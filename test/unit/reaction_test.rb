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
  test 'validates :inclusion of reactable_type' do
    %w(Issue Journal News Comment Message).each do |type|
      reaction = Reaction.new(reactable_type: type, user: User.new)
      assert reaction.valid?
    end

    assert_not Reaction.new(reactable_type: 'InvalidType', user: User.new).valid?
  end

  test 'scope: by' do
    user2_reactions = issues(:issues_001).reactions.by(users(:users_002))

    assert_equal [reactions(:reaction_002)], user2_reactions
  end
end
