# frozen_string_literal: true

class CreatePins < ActiveRecord::Migration[8.1]
  def change
    create_table :pins do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pinnable, polymorphic: true, null: false
      t.timestamps
    end

    add_index :pins, [:user_id, :pinnable_type, :pinnable_id], unique: true
  end
end
