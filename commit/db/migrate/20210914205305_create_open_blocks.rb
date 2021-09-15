class CreateOpenBlocks < ActiveRecord::Migration[6.0]
  def change
    create_table :open_blocks do |t|
      t.string :block_hash
      t.string :merkle_hash
      t.string :solution_hash
      t.string :prev_block_hash
      t.integer :nonce
      t.integer :difficulty
      t.integer :cleared_transactions
      t.timestamps
    end
  end
end
