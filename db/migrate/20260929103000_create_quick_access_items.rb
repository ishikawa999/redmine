class CreateQuickAccessItems < ActiveRecord::Migration[8.1]
  def change
    create_table :quick_access_items do |t|
      t.references :user, null: false, index: false
      t.references :target, polymorphic: true, null: false
      t.timestamps null: false
    end
    add_index :quick_access_items, [:user_id, :target_type, :target_id], unique: true
  end
end
