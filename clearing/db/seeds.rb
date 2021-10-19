# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
def compute_solution_hash(difficulty, merkle_hash, prev_block_hash)
  starting_zeros = ("0" * difficulty)
  nonce = 1
  loop do
    hash = Digest::SHA256.hexdigest(merkle_hash.to_s + nonce.to_s + prev_block_hash.to_s)
    if hash.start_with?(starting_zeros)
      return [nonce, hash]
    else
      nonce += 1
    end
  end
end

amount = 1000000000000
key = OpenSSL::PKey.read File.read "storage/private_key.pem"
address = Digest::SHA256.base64digest(key.public_key.to_s)
sender = "0000000000000000000000000000000000000000000="
digest = OpenSSL::Digest::SHA256.new
transaction_hash = Digest::SHA256.hexdigest(amount.to_f.to_s + address.to_s + 1.to_s + sender.to_s + key.public_key.to_s.to_s + 0.to_f.to_s)
difficulty = 2

genesis = Block.create(block_hash: "0000000000000000000000000000000000000000000000000000000000000ad0",
                       commit_hash: "abb2855ebfc303bf5e146868f532390c3a9d816717dcdbd2c8ce2846ea878224",
                       merkle_hash: transaction_hash,
                       solution_hash: "0000000000000000000000000000000000000000000000000000000000000000",
                       prev_block_hash: "0000000000000000000000000000000000000000000000000000000000000000",
                       nonce: 1,
                       difficulty: 1,
                       block_height: 0)

ConfirmedTransaction.create(
  amount: amount,
  destination: address,
  transaction_hash: transaction_hash,
  sender: "0000000000000000000000000000000000000000000=",
  sender_public_key: key.public_key.to_s,
  sender_signature: key.sign(digest, transaction_hash).unpack("H*").first, #we unpack the signiture so that it fits into our database as a string
  tx_fee: 0,
  status: "cleared",
  nonce: 1,
  transaction_index: 0,
  block_id: genesis.id,
)

amount = 0
transaction_hash = Digest::SHA256.hexdigest(amount.to_f.to_s + address.to_s + 2.to_s + sender.to_s + key.public_key.to_s.to_s + 0.to_f.to_s)
mine_results = compute_solution_hash(difficulty, transaction_hash, genesis.block_hash)
new_block1 = Block.create(block_hash: Digest::SHA256.hexdigest(genesis.commit_hash + mine_results[1]),
                          commit_hash: nil,
                          merkle_hash: transaction_hash,
                          solution_hash: mine_results[1],
                          prev_block_hash: genesis.block_hash,
                          nonce: mine_results[0],
                          difficulty: 2)

open_txn = ConfirmedTransaction.create(
  amount: amount,
  destination: "0aKRMjy4GmRKZ2Ui4Zc8z9fqYOLTzwu9QD/JkGLd5Qw=",
  transaction_hash: transaction_hash,
  sender: "0000000000000000000000000000000000000000000=",
  sender_public_key: key.public_key.to_s,
  sender_signature: key.sign(digest, transaction_hash).unpack("H*").first,
  tx_fee: 0,
  status: "cleared",
  nonce: 2,
  transaction_index: 0,
  block_id: new_block1.id,
)

new_block1.update(commit_hash: Digest::SHA256.hexdigest((open_txn.amount ? open_txn.amount.to_f.to_s : "") + (open_txn.destination ? open_txn.destination.to_s : "") + open_txn.nonce.to_s + open_txn.sender.to_s + open_txn.sender_public_key.to_s + open_txn.status.to_s + open_txn.tx_fee.to_f.to_s))

transaction_hash = Digest::SHA256.hexdigest(amount.to_f.to_s + address.to_s + 2.to_s + sender.to_s + key.public_key.to_s.to_s + 0.to_f.to_s)
mine_results = compute_solution_hash(difficulty, transaction_hash, new_block1.block_hash)
new_block2 = Block.create(block_hash: Digest::SHA256.hexdigest(new_block1.commit_hash + mine_results[1]),
                          commit_hash: nil,
                          merkle_hash: transaction_hash,
                          solution_hash: mine_results[1],
                          prev_block_hash: new_block1.block_hash,
                          nonce: mine_results[0],
                          difficulty: 2)

open_txn1 = ConfirmedTransaction.create(
  amount: amount,
  destination: "0aKRMjy4GmRKZ2Ui4Zc8z9fqYOLTzwu9QD/JkGLd5Qw=",
  transaction_hash: transaction_hash,
  sender: "0000000000000000000000000000000000000000000=",
  sender_public_key: key.public_key.to_s,
  sender_signature: key.sign(digest, transaction_hash).unpack("H*").first,
  tx_fee: 0,
  status: "cleared",
  nonce: 3,
  transaction_index: 0,
  block_id: new_block2.id,
)

Block.calculate_block_height
Account.update_all_account_balances
