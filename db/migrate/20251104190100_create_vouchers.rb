# frozen_string_literal: true

class CreateVouchers < ActiveRecord::Migration[8.1]
  def change
    create_table :vouchers do |t|
      t.string :title, null: false
      t.text :details, null: false
      t.datetime :redeemed_at

      t.timestamps
    end
  end
end
