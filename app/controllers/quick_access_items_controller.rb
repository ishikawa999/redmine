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

class QuickAccessItemsController < ApplicationController
  helper :issue_statuses

  before_action :require_login
  before_action :set_target_identity, only: [:create, :destroy]
  before_action :find_target, only: :create

  def index
    quick_access_items = visible_items(limit: nil)
    @quick_access_item_count = quick_access_items.size
    per_page = per_page_option
    # Removing the only row of the last page redirects back to that page, so
    # fall back to the last one that still has rows.
    last_page = [(@quick_access_item_count - 1) / per_page + 1, 1].max
    page = params['page'].to_i.clamp(1, last_page)
    @quick_access_item_pages = Paginator.new @quick_access_item_count, per_page, page
    @quick_access_items = quick_access_items.slice(@quick_access_item_pages.offset, per_page)
  end

  def preview
    # Reading one more than is shown tells whether older items are left out
    quick_access_items = visible_items(limit: QuickAccessItem::PREVIEW_LIMIT + 1)
    @quick_access_items_truncated = quick_access_items.size > QuickAccessItem::PREVIEW_LIMIT
    @quick_access_items = quick_access_items.first(QuickAccessItem::PREVIEW_LIMIT)
    render partial: "preview", layout: false
  end

  def create
    unless @target.visible?(User.current)
      render_403
      return
    end

    begin
      User.current.quick_access_items.create!(target: @target)
    rescue ActiveRecord::RecordInvalid => e
      # Adding what is already there is not an error
      raise unless e.record.errors.of_kind?(:target_id, :taken)
    end

    respond_after_write
  end

  def destroy
    @target = @target_class.find_by(id: @target_id)
    current_user_item.delete_all
    respond_after_write
  end

  private

  def visible_items(limit:)
    QuickAccessItem::VisibleReader.new(User.current).call(limit: limit)
  end

  def set_target_identity
    unless QuickAccessItem::TARGET_TYPES.include?(params[:target_type])
      render_404
      return
    end

    @target_class = params[:target_type].constantize
    @target_id = params[:target_id]
  end

  def find_target
    @target = @target_class.find(@target_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def current_user_item
    User.current.quick_access_items.where(
      target_type: @target_class.base_class.name,
      target_id: @target_id
    )
  end

  def respond_after_write
    respond_to do |format|
      format.js
      format.html { redirect_back_or_to quick_access_items_path, allow_other_host: false }
    end
  end
end
