# frozen_string_literal: true

class CreateCalendarDays < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_days do |t|
      t.date :day, null: false
      t.integer :stars, null: false, default: 0

      t.timestamps
    end

    add_index :calendar_days, :day, unique: true
  end
end
