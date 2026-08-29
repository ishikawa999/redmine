# frozen_string_literal: true

class PinsController < ApplicationController
  PINNABLE_CLASSES = {
    "Issue" => Issue,
    "WikiPage" => WikiPage,
    "Version" => Version
  }.freeze

  before_action :require_login
  before_action :set_pinnable_identity, only: [:create, :destroy]
  before_action :find_pinnable, only: :create

  def index
    @pins = visible_pins(limit: nil)
  end

  def preview
    @pins = visible_pins(limit: 5)
    render partial: "preview", layout: false
  end

  def create
    unless @pinnable.visible?(User.current)
      render_403
      return
    end

    begin
      User.current.pins.create!(pinnable: @pinnable)
    rescue ActiveRecord::RecordInvalid => e
      raise unless duplicate_pin?(e.record)
    rescue ActiveRecord::RecordNotUnique
      raise unless current_user_pin.exists?
    end

    respond_after_write
  end

  def destroy
    @pinnable = @pinnable_class.find_by(id: @pinnable_id)
    current_user_pin.delete_all
    respond_after_write
  end

  private

  def visible_pins(limit:)
    Pin::VisibleReader.new(User.current).call(limit: limit)
  end

  def set_pinnable_identity
    @pinnable_class = PINNABLE_CLASSES[params[:pinnable_type]]
    unless @pinnable_class
      render_404
      return
    end

    @pinnable_id = params[:pinnable_id]
  end

  def find_pinnable
    @pinnable = @pinnable_class.find(@pinnable_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def current_user_pin
    User.current.pins.where(
      pinnable_type: @pinnable_class.base_class.name,
      pinnable_id: @pinnable_id
    )
  end

  def duplicate_pin?(pin)
    pin.pinnable_type == @pinnable_class.base_class.name &&
      pin.pinnable_id.to_s == @pinnable_id.to_s &&
      current_user_pin.exists?
  end

  def respond_after_write
    respond_to do |format|
      format.js { head :ok }
      format.html { redirect_back_or_to pins_path, allow_other_host: false }
    end
  end
end
