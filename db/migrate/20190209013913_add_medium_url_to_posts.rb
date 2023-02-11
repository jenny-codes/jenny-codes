# frozen_string_literal: true

class AddMediumUrlToPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :medium_url, :string, unique: true
  end
end
