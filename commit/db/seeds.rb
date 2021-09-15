# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
new_block = Block.create(block_hash: new_block_hash,
                         commit_hash: nil,
                         merkle_hash: parse_input["merkle_hash"],
                         solution_hash: parse_input["solution_hash"],
                         prev_block_hash: parse_input["prev_block_hash"],
                         nonce: parse_input["nonce"],
                         difficulty: parse_input["difficulty"])

#append the new block with it's block hash to the chain with all transactions set to "waiting"
parse_input["transactions"].sort_by { |k| k["transaction_index"].to_i }.each { |new_txn|
  ConfirmedTransaction.create(
    amount: new_txn["amount"],
    destination: new_txn["destination"],
    transaction_hash: new_txn["transaction_hash"],
    sender: new_txn["sender"],
    sender_public_key: new_txn["sender_public_key"],
    sender_signature: new_txn["sender_signature"],
    tx_fee: new_txn["tx_fee"],
    status: "waiting",
    nonce: new_txn["nonce"],
    block_id: new_block.id,
  )
}

#Open a new temporary block as well to verify newly cleared blocks against.
new_open_block = OpenBlock.create(block_hash: new_block_hash,
                                  commit_hash: nil,
                                  merkle_hash: parse_input["merkle_hash"],
                                  solution_hash: parse_input["solution_hash"],
                                  prev_block_hash: parse_input["prev_block_hash"],
                                  nonce: parse_input["nonce"],
                                  difficulty: parse_input["difficulty"],
                                  clear_transactions: 0)

#append the new block with it's block hash to the chain with all transactions set to "waiting"
parse_input["transactions"].sort_by { |k| k["transaction_index"].to_i }.each { |new_txn|
  OpenTransaction.create(
    amount: new_txn["amount"],
    destination: new_txn["destination"],
    transaction_hash: new_txn["transaction_hash"],
    sender: new_txn["sender"],
    sender_public_key: new_txn["sender_public_key"],
    sender_signature: new_txn["sender_signature"],
    tx_fee: new_txn["tx_fee"],
    status: "waiting",
    nonce: new_txn["nonce"],
    block_id: new_open_block.id,
  )
}
