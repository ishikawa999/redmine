# frozen_string_literal: true

class QuickAccessItemsController < ApplicationController
  TARGET_CLASSES = {
    "Issue" => Issue,
    "WikiPage" => WikiPage,
    "Version" => Version
  }.freeze

  before_action :require_login
  before_action :set_target_identity, only: [:create, :destroy]
  before_action :find_target, only: :create

  def index
    @quick_access_items = visible_items(limit: nil)
  end

  def preview
    @quick_access_items = visible_items(limit: 5)
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
      raise unless duplicate_item?(e.record)
    rescue ActiveRecord::RecordNotUnique
      raise unless current_user_item.exists?
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
    @target_class = TARGET_CLASSES[params[:target_type]]
    unless @target_class
      render_404
      return
    end

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

  def duplicate_item?(item)
    item.target_type == @target_class.base_class.name &&
      item.target_id.to_s == @target_id.to_s &&
      current_user_item.exists?
  end

  def respond_after_write
    respond_to do |format|
      format.js
      format.html { redirect_back_or_to quick_access_items_path, allow_other_host: false }
    end
  end
end
