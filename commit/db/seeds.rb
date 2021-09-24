# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

amount = 1000000000000
key = OpenSSL::PKey.read File.read "storage/private_key.pem"
address = Digest::SHA256.base64digest(key.public_key.to_s)
sender = "0000000000000000000000000000000000000000000000000000000000000000"
digest = OpenSSL::Digest::SHA256.new
transaction_hash = Digest::SHA256.hexdigest(amount.to_s + address.to_s + 1.to_s + sender.to_s + key.public_key.to_s.to_s + 0.to_s)

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
  sender: "0000000000000000000000000000000000000000000000000000000000000000",
  sender_public_key: key.public_key.to_s,
  sender_signature: key.sign(digest, transaction_hash).unpack("H*").first, #we unpack the signiture so that it fits into our database as a string
  tx_fee: 0,
  status: "cleared",
  nonce: 1,
  transaction_index: 0,
  block_id: genesis.id,
)

transaction_hash = Digest::SHA256.hexdigest(amount.to_s + address.to_s + 2.to_s + sender.to_s + key.public_key.to_s.to_s + 0.to_s)
new_block1 = Block.create(block_hash: "0000000000000000000000000000000000000000000000000000000000000ad1",
                          commit_hash: "c50b22a7a983fd0e9d38d18aec48b2626942b136f66714c12629ac47b5009bd6",
                          merkle_hash: transaction_hash,
                          solution_hash: "0021a3af0189201ff02c0803d554b91306723300b85f7999e59b16a45fbf59f0",
                          prev_block_hash: "0000000000000000000000000000000000000000000000000000000000000ad0",
                          nonce: 497,
                          difficulty: 1)

ConfirmedTransaction.create(
  amount: amount,
  destination: "0aKRMjy4GmRKZ2Ui4Zc8z9fqYOLTzwu9QD/JkGLd5Qw=",
  transaction_hash: transaction_hash,
  sender: "0000000000000000000000000000000000000000000000000000000000000000",
  sender_public_key: key.public_key.to_s,
  sender_signature: key.sign(digest, transaction_hash).unpack("H*").first,
  tx_fee: 0,
  status: "cleared",
  nonce: 2,
  transaction_index: 0,
  block_id: new_block1.id,
)

amount = 0
transaction_hash = Digest::SHA256.hexdigest(amount.to_s + address.to_s + 3.to_s + sender.to_s + key.public_key.to_s.to_s + 0.to_s)
new_block2 = Block.create(block_hash: "00c1d07d532fb58597f17c04afb557e7cd52b336fb7f7e7093fb707752b3b826",
                          commit_hash: nil,
                          merkle_hash: transaction_hash,
                          solution_hash: "0d3a6c8ef526141240dfc96aa0c2228663f7357258e982557b7595cc30e0dcb9",
                          prev_block_hash: "0000000000000000000000000000000000000000000000000000000000000ad1",
                          nonce: 15,
                          difficulty: 1)

ConfirmedTransaction.create(
  amount: amount,
  destination: "0aKRMjy4GmRKZ2Ui4Zc8z9fqYOLTzwu9QD/JkGLd5Qw=",
  transaction_hash: transaction_hash,
  sender: "0000000000000000000000000000000000000000000000000000000000000000",
  sender_public_key: key.public_key.to_s,
  sender_signature: key.sign(digest, transaction_hash).unpack("H*").first,
  tx_fee: 0,
  status: "pre-cleared",
  nonce: 2,
  transaction_index: 0,
  block_id: new_block2.id,
)

new_open_block2 = OpenBlock.create(block_hash: "00c1d07d532fb58597f17c04afb557e7cd52b336fb7f7e7093fb707752b3b826",
                                   merkle_hash: transaction_hash,
                                   solution_hash: "0d3a6c8ef526141240dfc96aa0c2228663f7357258e982557b7595cc30e0dcb9",
                                   prev_block_hash: "0000000000000000000000000000000000000000000000000000000000000ad1",
                                   nonce: 15,
                                   difficulty: 1)

OpenTransaction.create(
  amount: amount,
  destination: "0aKRMjy4GmRKZ2Ui4Zc8z9fqYOLTzwu9QD/JkGLd5Qw=",
  transaction_hash: transaction_hash,
  sender: "0000000000000000000000000000000000000000000000000000000000000000",
  sender_public_key: key.public_key.to_s,
  sender_signature: key.sign(digest, transaction_hash).unpack("H*").first,
  tx_fee: 0,
  status: "pre-cleared",
  nonce: 3,
  transaction_index: 0,
  open_block_id: new_open_block2.id,
)
