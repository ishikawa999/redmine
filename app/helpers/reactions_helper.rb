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

module ReactionsHelper
  DISPLAY_REACTION_USERS_LIMIT = 10

  def reaction_button(object, reaction = nil)
    return unless Setting.reactions_enabled? && object.visible?(User.current)

    reaction ||= object.reaction_by(User.current)

    render 'reactions/button',
      reaction_id: reaction_id_for(object),
      object: object,
      reaction: reaction,
      reaction_count: object.reactions.size,
      reaction_tooltip: reaction_tooltip_for(object)
  end

  def reaction_id_for(object)
    dom_id(object, :reaction)
  end

  private

  def reaction_tooltip_for(object)
    reaction_count = object.reaction_users.size

    return if reaction_count.zero?

    user_names = object.reaction_users.take(DISPLAY_REACTION_USERS_LIMIT).map(&:name)

    if reaction_count > DISPLAY_REACTION_USERS_LIMIT
      others = reaction_count - DISPLAY_REACTION_USERS_LIMIT
      user_names << I18n.t(:reaction_text_other_users, others: others)
    end

    user_names.to_sentence(locale: I18n.locale)
  end
end
