class CreateConfirmedTransactions < ActiveRecord::Migration[6.0]
  def change
    create_table :confirmed_transactions do |t|
      t.float :amount
      t.string :destination
      t.string :transaction_hash
      t.string :sender
      t.string :sender_public_key
      t.string :sender_signature
      t.float :tx_fee
      t.string :status
      t.integer :nonce
      t.references :block, null: false, foreign_key: true

      t.timestamps
    end
  end
end
