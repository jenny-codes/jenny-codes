class AddMediumUrlToPosts < ActiveRecord::Migration[5.2]
  def change
    add_column :posts, :medium_url, :string, unique: true
  end
end
