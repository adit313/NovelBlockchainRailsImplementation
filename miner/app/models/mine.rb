require "net/http"

class Mine < ApplicationRecord
  def self.mine_next_block
    #check to see if there are transactions
    if UnconfirmedTransaction.all.count > 0
      #if there are, select which ones to incorporate into a new block
      active_record_proposed_block_transactions = UnconfirmedTransaction.limit(MAX_BLOCK_TRANSACTIONS - 2).order(tx_fee: :desc, transaction_hash: :desc)
      #add up fees and append coinbase transation with all fees using miner public address key
      total_fees = active_record_proposed_block_transactions.pluck(:tx_fee).sum / 2

      sender = "0000000000000000000000000000000000000000000000000000000000000000"
      digest = OpenSSL::Digest::SHA256.new
      transaction_hash = Digest::SHA256.hexdigest(total_fees.to_s + COMMIT_NODE_ADDRESS.to_s + 1.to_s + sender.to_s + COMMIT_NODE_KEY.public_key.to_s.to_s + 0.to_f.to_s)
      signature = COMMIT_NODE_KEY.sign(digest, transaction_hash).unpack("H*").first

      coinbase_transaction = UnconfirmedTransaction.new(amount: total_fees,
                                                        destination: COMMIT_NODE_ADDRESS,
                                                        nonce: 1,
                                                        sender: sender,
                                                        sender_public_key: COMMIT_NODE_KEY.public_key.to_s,
                                                        sender_signature: signature,
                                                        transaction_hash: transaction_hash,
                                                        tx_fee: 0,
                                                        transaction_index: 0)
      proposed_block_transactions = active_record_proposed_block_transactions.order(tx_fee: :asc).to_a
      proposed_block_transactions << coinbase_transaction
      proposed_block_transactions.reverse!
      #assign transaction index
      index = 1
      proposed_block_transactions.each { |txn|
        if txn.sender != sender
          txn.update(transaction_index: index)
          index += 1
        end
      }
      #calculate merkle hash
      merkle_tree_hash = Mine.compute_transaction_merkle_tree(proposed_block_transactions.pluck(:transaction_hash))
      #calclate solution hash
      prev_block_hash = Block.highest_block.block_hash
      block_result = Mine.compute_solution_hash(BLOCK_DIFFICULTY, merkle_tree_hash, prev_block_hash)
      #on successful calculation, make new block
      newly_mined_block = Block.new(block_hash: nil,
                                    commit_hash: nil,
                                    merkle_hash: merkle_tree_hash,
                                    prev_block_hash: prev_block_hash,
                                    nonce: (block_result[0]),
                                    solution_hash: block_result[1],
                                    difficulty: BLOCK_DIFFICULTY)
      #and prepare the json to commit node network
      transmit_hash = newly_mined_block.attributes
      transactions_array = []
      proposed_block_transactions.each { |txn|
        transactions_array << txn.attributes
      }
      transmit_hash["confirmed_transactions"] = transactions_array
      #transmit to commit node network
      payload = transmit_hash.to_json
      #if successful
      broadcast_to_commit_node_network(payload)
      #received_block.save and delete those transactions from the pool
    else
      sleep(10) #wait 10 seconds to see if new transactions post
    end
  end

  def self.broadcast_to_commit_node_network(payload)
    #POST request to commit.stardust.finance
    Net::HTTP.post(URI("http://commit.stardust.finance/commit"), payload, "Content-Type" => "application/json")
  end

  # a recursive function to find the merkle root of the transactions
  def self.compute_transaction_merkle_tree(transaction_hashes)
    if transaction_hashes.empty?
      return "0"
    elsif transaction_hashes.length == 1
      return transaction_hashes[0]
    else
      transaction_hashes << transaction_hashes[-1] if transaction_hashes.size % 2 != 0

      new_hashes = []
      transaction_hashes.each_slice(2) do |txn_hash|
        hash = Digest::SHA256.hexdigest(txn_hash[0] + txn_hash[1])
        new_hashes << hash
      end
      return compute_transaction_merkle_tree(new_hashes)
    end
  end

  # a simple calculator to find the solution hash.
  def self.compute_solution_hash(difficulty, merkle_hash, prev_block_hash)
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
end
