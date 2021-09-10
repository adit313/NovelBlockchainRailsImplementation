class CreateAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :accounts do |t|
      t.string :account_id
      t.float :confirmed_balance
      t.integer :highest_nonce

      t.timestamps
    end
  end
end
