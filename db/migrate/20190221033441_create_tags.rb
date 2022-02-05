# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[5.2]
  def change
    create_table :tags do |t|
      t.string :text
      # t.belongs_to :taggable, :polymorphic => true

      t.timestamps
    end
  end
end
