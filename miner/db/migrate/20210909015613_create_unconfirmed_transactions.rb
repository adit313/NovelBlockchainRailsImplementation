class CreateUnconfirmedTransactions < ActiveRecord::Migration[6.0]
  def change
    create_table :unconfirmed_transactions do |t|
      t.float :amount
      t.string :destination
      t.string :transaction_hash
      t.string :sender
      t.string :sender_public_key
      t.string :sender_signature
      t.float :tx_fee
      t.integer :nonce
      t.integer :transaction_index

      t.timestamps
    end
  end
end
