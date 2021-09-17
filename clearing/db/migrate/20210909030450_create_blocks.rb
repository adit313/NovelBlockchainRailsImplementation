class CreateBlocks < ActiveRecord::Migration[6.0]
  def change
    create_table :blocks do |t|
      t.string :block_hash
      t.string :commit_hash
      t.string :merkle_hash
      t.string :solution_hash
      t.string :prev_block_hash
      t.integer :block_height
      t.integer :nonce
      t.integer :difficulty

      t.timestamps
    end
  end
end
