class CreateMartSoaps < ActiveRecord::Migration
  def self.up
    create_table :mart_soaps do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :mart_soaps
  end
end
