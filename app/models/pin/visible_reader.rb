# frozen_string_literal: true

class Pin::VisibleReader
  BATCH_SIZE = 5

  def initialize(user)
    @user = user
  end

  def call(limit: nil)
    raise ArgumentError, "limit must be a positive integer" if limit && (!limit.is_a?(Integer) || limit <= 0)

    visible_pins = []
    cursor = nil

    loop do
      batch = next_batch(cursor)
      break if batch.empty?

      preload_targets_and_projects(batch)
      batch.each do |pin|
        visible_pins << pin if visible?(pin)
        return visible_pins if limit && visible_pins.size == limit
      end

      last_pin = batch.last
      cursor = [last_pin.created_at, last_pin.id]
    end

    visible_pins
  end

  private

  def next_batch(cursor)
    scope = Pin.where(user: @user).recent_first
    if cursor
      created_at, id = cursor
      scope = scope.where(
        "pins.created_at < :created_at OR (pins.created_at = :created_at AND pins.id < :id)",
        created_at: created_at,
        id: id
      )
    end
    scope.limit(BATCH_SIZE).to_a
  end

  def preload_targets_and_projects(pins)
    preload(pins, :pinnable)

    targets = pins.filter_map(&:pinnable)
    preload(targets.grep(Issue), :project)
    preload(targets.grep(Version), :project)

    wiki_pages = targets.grep(WikiPage)
    preload(wiki_pages, :wiki)
    preload(wiki_pages.filter_map(&:wiki), :project)
  end

  def preload(records, associations)
    return if records.empty?

    ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
  end

  def visible?(pin)
    pin.pinnable.present? && pin.pinnable.visible?(@user)
  rescue ActiveRecord::RecordNotFound
    false
  end
end
