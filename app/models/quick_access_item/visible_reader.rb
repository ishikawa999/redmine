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

class QuickAccessItem::VisibleReader
  BATCH_SIZE = 10

  def initialize(user)
    @user = user
  end

  def call(limit: nil)
    raise ArgumentError, "limit must be a positive integer" if limit && (!limit.is_a?(Integer) || limit <= 0)
    return all_visible_items unless limit

    visible_items = []
    cursor = nil

    loop do
      batch = next_batch(cursor)
      break if batch.empty?

      preload_targets_and_projects(batch)
      batch.each do |item|
        visible_items << item if visible?(item)
        return visible_items if visible_items.size == limit
      end

      last_item = batch.last
      cursor = [last_item.created_at, last_item.id]
    end

    visible_items
  end

  private

  # Every item is needed without a limit, so read them in a single pass.
  # Reading in batches would reload the projects of each batch and cost
  # queries in proportion to the number of items.
  def all_visible_items
    quick_access_items = QuickAccessItem.where(user: @user).recent_first.to_a
    preload_targets_and_projects(quick_access_items)
    quick_access_items.select {|item| visible?(item)}
  end

  def next_batch(cursor)
    scope = QuickAccessItem.where(user: @user).recent_first
    if cursor
      created_at, id = cursor
      scope = scope.where(
        "quick_access_items.created_at < :created_at OR (quick_access_items.created_at = :created_at AND quick_access_items.id < :id)",
        created_at: created_at,
        id: id
      )
    end
    scope.limit(BATCH_SIZE).to_a
  end

  def preload_targets_and_projects(quick_access_items)
    preload(quick_access_items, :target)

    targets = quick_access_items.filter_map(&:target)
    preload(targets.grep(Issue), [:project, :tracker, :status])
    preload(targets.grep(Version), :project)

    wiki_pages = targets.grep(WikiPage)
    preload(wiki_pages, :wiki)
    preload(wiki_pages.filter_map(&:wiki), :project)
  end

  def preload(records, associations)
    return if records.empty?

    ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
  end

  def visible?(item)
    item.target.present? && item.target.visible?(@user)
  rescue ActiveRecord::RecordNotFound
    false
  end
end
