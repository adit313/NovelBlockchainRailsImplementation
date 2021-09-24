require "net/http"

class Block < ApplicationRecord
  has_many :confirmed_transactions
  validates :block_hash, uniqueness: true
  validates :block_hash, :solution_hash, :merkle_hash, :prev_block_hash, :nonce, :difficulty, presence: true
  validates :block_hash, length: { is: 64 }
  validates :merkle_hash, length: { is: 64 }
  validates :solution_hash, length: { is: 64 }
  validates :prev_block_hash, length: { is: 64 }

  def self.validate_new_mined_block(json_input)
    if json_input.is_a?(String)
      begin
        parse_input = JSON.parse(json_input)
      rescue
        return "JSON is not Valid"
      end
    else
      return "Block inputed was not a JSON String"
    end
    #check to see if the block from the mining node is valid
    block_test = Block.generic_block_check(json_input)
    return block_test if block_test
    #check transactions
    txn_test = Block.block_unappended_transaction_test(json_input)
    return txn_test if txn_test
    #check merkle tree
    merkle_check = Block.merkle_check(json_input)
    if merkle_check != parse_input["merkle_hash"]
      return "Block merkle root did not match transaction merkle root"
    end
    #check to make sure this block is at the end of the chain
    prev_block_hash = parse_input["prev_block_hash"].to_s

    prev_block = nil

    CLEARING_WINDOW.times do
      prev_block = Block.find_by(block_hash: prev_block_hash)
      if !prev_block
        return "Previous block was not found on this node's chain"
      end
      prev_block_hash = prev_block.prev_block_hash
    end
    #if valid, perform the commit process
    Block.commit_new_block(parse_input, prev_block)
  end

  def self.commit_new_block(parse_input, replace_block) #replace_block is the block that needs to be closed

    #get open block that has transactions appended from memory
    open_block = OpenBlock.find_by(block_hash: replace_block.block_hash)

    #close the open_block
    commit_hash = open_block.close

    #update all the transaction
    temp_open_transactions = open_block.open_transactions.order(:transaction_index)
    replace_block.confirmed_transactions.order(:transaction_index).each_with_index { |txn_to_replace, index|
      replacement_transaction_info = temp_open_transactions[index].attributes
      replacement_transaction_info.delete("open_block_id")
      replacement_transaction_info.delete("id")
      txn_to_replace.update(replacement_transaction_info)
    }

    #Now that the block has updated transactions in it, we write the commit hash
    replace_block.update(commit_hash: commit_hash)

    #We now use that commit hash and the solution hash of the newly mined block to write the block hash of the new block
    new_block_hash = Digest::SHA256.hexdigest(commit_hash + parse_input["solution_hash"])
    new_block = Block.create(block_hash: new_block_hash,
                             commit_hash: nil,
                             merkle_hash: parse_input["merkle_hash"],
                             solution_hash: parse_input["solution_hash"],
                             prev_block_hash: parse_input["prev_block_hash"],
                             nonce: parse_input["nonce"],
                             difficulty: parse_input["difficulty"])

    #append the new block with it's block hash to the chain with all transactions set to "waiting"
    parse_input["confirmed_transactions"].sort_by { |k| k["transaction_index"].to_i }.each { |new_txn|
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
        transaction_index: new_txn["transaction_index"],
        block_id: new_block.id,
      )
    }

    #Open a new temporary block as well to verify newly cleared blocks against.
    new_open_block = OpenBlock.create(block_hash: new_block_hash,
                                      merkle_hash: parse_input["merkle_hash"],
                                      solution_hash: parse_input["solution_hash"],
                                      prev_block_hash: parse_input["prev_block_hash"],
                                      nonce: parse_input["nonce"],
                                      difficulty: parse_input["difficulty"],
                                      cleared_transactions: 0)

    #append the new block with it's block hash to the chain with all transactions set to "waiting"
    parse_input["confirmed_transactions"].sort_by { |k| k["transaction_index"].to_i }.each { |new_txn|
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
        transaction_index: new_txn["transaction_index"],
        open_block_id: new_open_block.id,
      )
    }

    #delete the temporary block in memory
    open_block.destroy

    #update internal account database
    accounts_to_update = (replace_block.confirmed_transactions.pluck(:destination) + replace_block.confirmed_transactions.pluck(:sender)).uniq
    Account.update_balances_in_new_block(accounts_to_update)
    #broadcast the new blocks to all networks
    transmit_new_blocks_to_network(replace_block, new_block)
    #return message to sender
    return "Block accepted"
  end

  def self.transmit_new_blocks_to_network(replace_block, new_block)
    payload = [replace_block, new_block].to_json(:include => :confirmed_transactions)
    #POST "/block" to other commit nodes
    # Net::HTTP.post(URI("http://mining.stardust.finance/block"), payload, "Content-Type" => "application/json")

    #POST "/block" to mining.stardust.finance
    Net::HTTP.post(URI("http://mining.stardust.finance/block"), payload, "Content-Type" => "application/json")

    #POST "/block" to clearing.stardust.finance
    Net::HTTP.post(URI("http://clearing.stardust.finance/block"), payload, "Content-Type" => "application/json")
  end

  def self.validate_new_cleared_block(json_input)
    if json_input.is_a?(String)
      begin
        parse_input = JSON.parse(json_input)
      rescue
        return "JSON is not Valid"
      end
    else
      return "Block inputed was not a JSON String"
    end

    #check to ensure block exists in memory and is open
    current_block = OpenBlock.find_by(block_hash: json_input["block_hash"])
    if !current_block
      return "Could not locate open block with this block hash"
    end

    #check to see if the block from the clearing node is valid
    block_test = Block.generic_block_check(json_input)
    return block_test if block_test

    #check transactions
    if json_input["transactions"].length != current_block.open_transactions.length
      return "The posted block did not match the transactions of the "
    end
    txn_test = Block.block_unappended_transaction_test(json_input)
    return txn_test if txn_test

    #check merkle tree
    merkle_check = Block.merkle_check(json_input)
    if merkle_check != parse_input["merkle_hash"]
      return "Block merkle root did not match transaction merkle root"
    end

    # check to see if block is more cleared than current block and not closed

    # need to develop better logic about transaction verification in the event of a
    # malicious clearing node, current solution is for commit network to independently
    # verify transaction and assess a penalty to that node
    # This functionality has not yet been implemented in this version

    post_cleared_transactions = 0

    json_input["transactions"].each { |txn|
      if txn.transaction_index != 0
        if txn.status == "Pre-Cleared"
          calculated_hash = Digest::SHA256.hexdigest(txn["amount"].to_s + txn["destination"].to_s + txn["nonce"].to_s + txn["sender"].to_s + txn["sender_public_key"].to_s + txn["tx_fee"].to_s)
          if calculated_hash != txn["transaction_hash"]
            return "A transaction hash did not match the SHA256 hex Hash of (amount + destination + nonce + sender + sender_public_key + tx_fee)"
          else
            post_cleared_transactions += 1
          end
        end
      end
    }

    #if yes, replace block
    if post_cleared_transactions > current_block.cleared_transactions
      #delete the old block and the old transactions
      current_block.destroy

      #Create a newly cleared blocks to verify future cleared blocks against.
      new_open_block = OpenBlock.create(block_hash: parse_input["block_hash"],
                                        commit_hash: nil,
                                        merkle_hash: parse_input["merkle_hash"],
                                        solution_hash: parse_input["solution_hash"],
                                        prev_block_hash: parse_input["prev_block_hash"],
                                        nonce: parse_input["nonce"],
                                        difficulty: parse_input["difficulty"],
                                        clear_transactions: post_cleared_transactions)

      #append the new block with it's block hash to the chain with all transactions set to "waiting"
      parse_input["confirmed_transactions"].sort_by { |k| k["transaction_index"].to_i }.each { |new_txn|
        OpenTransaction.create(amount: new_txn["amount"],
                               destination: new_txn["destination"],
                               transaction_hash: new_txn["transaction_hash"],
                               sender: new_txn["sender"],
                               sender_public_key: new_txn["sender_public_key"],
                               sender_signature: new_txn["sender_signature"],
                               tx_fee: new_txn["tx_fee"],
                               status: new_txn["status"],
                               nonce: new_txn["nonce"],
                               transaction_index: new_txn["transaction_index"],
                               block_id: new_open_block.id)
      }

      return "Replaced cleared block"
    end
  end

  def self.generic_block_check(json_input)
    if json_input.is_a?(String)
      begin
        parse_input = JSON.parse(json_input)
      rescue
        return "JSON is not Valid"
      end
    else
      return "Block inputed was not a JSON String"
    end

    if !parse_input["merkle_hash"] || parse_input["merkle_hash"].length != 64
      return "All blocks must have a valid merkle_hash"
    end

    if !parse_input["solution_hash"] || parse_input["solution_hash"].length != 64
      return "All blocks must have a valid solution hash"
    end

    if !parse_input["prev_block_hash"] || parse_input["prev_block_hash"].length != 64
      return "All blocks must have a valid previous block hash"
    end

    if !parse_input["nonce"] || parse_input["nonce"].to_i <= 0
      return "All blocks must have a valid nonce"
    end

    if !parse_input["difficulty"] || parse_input["difficulty"].to_i <= 0
      return "All blocks must have a valid difficulty"
    end

    calculated_hash = Digest::SHA256.hexdigest(parse_input["merkle_hash"].to_s + parse_input["nonce"].to_s + parse_input["prev_block_hash"].to_s)

    if calculated_hash != parse_input["solution_hash"]
      return "The solution hash did not match the SHA256 hex hash of (merkle_hash + nonce + prev_block_hash)"
    end

    starting_zeros = ("0" * parse_input["difficulty"].to_i)
    if !parse_input["solution_hash"].start_with?(starting_zeros)
      return "The solution hash did not satisfy the difficulty function"
    end

    if parse_input["commit_hash"]
      txn_hash_w_status = []
      #fail all of the open transactions
      parse_input["confirmed_transactions"].sort { |e| e["transaction_index"] }.each { |open_txn|
        #SHA256 all the transactions along with their statuses
        txn_hash_w_status << Digest::SHA256.hexdigest((open_txn.amount ? open_txn.amount.to_s : "") + (open_txn.destination ? open_txn.destination.to_s : "") + open_txn.nonce.to_s + open_txn.sender.to_s + open_txn.sender_public_key.to_s + open_txn.status.to_s + open_txn.tx_fee.to_s)
      }
      test_commit_hash = Block.compute_transaction_merkle_tree(txn_hash_w_status)
      if parse_input["commit_hash"] != test_commit_hash
        return "Block had a commit hash that didn't match the merkle root of the transactions appended with their statuses"
      end
    end
  end

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

  def self.block_unappended_transaction_test(json_input)
    parse_input = JSON.parse(json_input)
    block_transactions = parse_input["confirmed_transactions"]
    if block_transactions.class != Array
      return "Transactions were not properly formatted as an array"
    end
    coinbase_transaction_count = 0
    coinbase_amount_to_verify = 0
    total_fees = 0

    block_transactions.each { |txn|
      total_fees += txn["tx_fee"]
      if txn["sender"] == "0000000000000000000000000000000000000000000000000000000000000000"
        ConfirmedTransaction.coinbase_transaction_check(txn.to_json)
        coinbase_transaction_count += 1
        coinbase_amount_to_verify += txn["amount"]
      else
        txn_test = ConfirmedTransaction.generic_transaction_check(txn.to_json)
        if txn_test
          return txn_test
        end

        if !txn["transaction_index"]
          return "All transactions must have an index"
        end
      end
    }
    if coinbase_transaction_count > 2
      return "There are only 2 coinbase transactions in a valid block"
    end

    if coinbase_amount_to_verify > total_fees
      return "This block has a higher coinbase transaction amount than its transaction fee total"
    end
  end

  def self.merkle_check(json_input)
    parse_input = JSON.parse(json_input)
    block_transactions = parse_input["confirmed_transactions"]
    if block_transactions.class != Array
      return "Transactions were not properly formatted as an array"
    end
    hashes = []
    block_transactions.sort_by { |k| k["transaction_index"] }.each { |txn|
      hashes << txn["transaction_hash"]
    }
    return Block.compute_transaction_merkle_tree(hashes)
  end

  def self.highest_block
    Block.calculate_block_height
    Block.order(block_height: :desc).first
  end

  def self.calculate_block_height
    Block.all.each { |block|
      if !block.block_height
        Block.find_height(block)
      end
    }
  end

  def self.find_height(block)
    prev_block = Block.find_by(block_hash: block.prev_block_hash)
    if prev_block.block_height
      block_height = prev_block.block_height + 1
      block.update(block_height: block_height)
      return block_height
    else
      block_height = Block.find_height(prev_block) + 1
      block.update(block_height: block_height)
      return block_height
    end
  end

  #################################
  def self.validate_newly_received_block(json_input)
    if json_input.is_a?(String)
      begin
        parse_input = JSON.parse(json_input)
      rescue
        return "JSON is not Valid"
      end
    else
      return "Block inputed was not a JSON String"
    end
    #check to see if the block from the mining node is valid
    block_test = Block.generic_block_check(json_input)
    return block_test if block_test
    #check transactions
    txn_test = Block.block_unappended_transaction_test(json_input)
    return txn_test if txn_test
    #check merkle tree
    merkle_check = Block.merkle_check(json_input)
    if merkle_check != parse_input["merkle_hash"]
      return "Block merkle root did not match transaction merkle root"
    end

    #check to make sure this block is at the end of the chain
    prev_block_hash = parse_input["prev_block_hash"].to_s

    prev_block = nil

    CLEARING_WINDOW.times do
      prev_block = Block.find_by(block_hash: prev_block_hash)
      if !prev_block
        return "Previous block was not found on this node's chain"
      end
      prev_block_hash = prev_block.prev_block_hash
    end

    if prev_block.commit_hash
      if parse_input["block_hash"] != Digest::SHA256.hexdigest(prev_block.commit_hash + parse_input["solution_hash"])
        return "The block hash does not match this SHA256 Hash of the commit hash of the associated block at the end of the clearing window appended to the solution hash"
      end
    end

    #if valid, add to memory or update if on chain
    pre_existing_block = Block.find_by(block_hash: parse_input["block_hash"], commit_hash: parse_input["commit_hash"])
    if pre_existing_block
      Block.update_block_from_json(parse_input, pre_existing_block)
    else
      pre_existing_block = Block.find_by(block_hash: parse_input["block_hash"])
      if pre_existing_block && pre_existing_block.commit_hash == nil
        Block.update_block_from_json(parse_input, pre_existing_block)
      else
        pre_existing_block = Block.new_block_from_json(parse_input)
      end
    end
    accounts_to_update = (pre_existing_block.confirmed_transactions.pluck(:destination) + pre_existing_block.confirmed_transactions.pluck(:sender)).uniq
    Account.update_balances_in_new_block(accounts_to_update)
  end

  def self.new_block_from_json(parse_input)
    new_block = Block.create(block_hash: parse_input["block_hash"],
                             commit_hash: parse_input["commit_hash"],
                             merkle_hash: parse_input["merkle_hash"],
                             solution_hash: parse_input["solution_hash"],
                             prev_block_hash: parse_input["prev_block_hash"],
                             nonce: parse_input["nonce"],
                             difficulty: parse_input["difficulty"])

    #append the new block with it's block hash to the chain with all transactions set to "waiting"
    parse_input["confirmed_transactions"].sort_by { |k| k["transaction_index"].to_i }.each { |new_txn|
      ConfirmedTransaction.create(
        amount: new_txn["amount"],
        destination: new_txn["destination"],
        transaction_hash: new_txn["transaction_hash"],
        sender: new_txn["sender"],
        sender_public_key: new_txn["sender_public_key"],
        sender_signature: new_txn["sender_signature"],
        tx_fee: new_txn["tx_fee"],
        status: new_txn["status"],
        nonce: new_txn["nonce"],
        transaction_index: new_txn["transaction_index"],
        block_id: new_block.id,
      )
    }
    return new_block
  end

  def self.update_block_from_json(parse_input, block_to_replace)
    #update block commit hash
    block_to_replace.update(commit_hash: parse_input["commit_hash"])

    #update all the transaction
    temp_parsed_transactions = parse_input["confirmed_transactions"].sort { |e| e["transaction_index"] }

    block_to_replace.confirmed_transactions.order(:transaction_index).each_with_index { |txn_to_replace, index|
      replacement_transaction_info = temp_parsed_transactions[index]
      replacement_transaction_info.delete("id")
      txn_to_replace.update(replacement_transaction_info)
    }
  end

  def commit_hash_check()
    txn_hash_w_status = []
    #fail all of the open transactions
    self.confirmed_transactions.order(:transaction_index).each { |open_txn|
      txn_hash_w_status << Digest::SHA256.hexdigest((open_txn.amount ? open_txn.amount.to_s : "") + (open_txn.destination ? open_txn.destination.to_s : "") + open_txn.nonce.to_s + open_txn.sender.to_s + open_txn.sender_public_key.to_s + open_txn.status.to_s + open_txn.tx_fee.to_s)
    }
    commit_hash = Block.compute_transaction_merkle_tree(txn_hash_w_status)
    return commit_hash
  end
end

#code to render block
#Block.includes(:confirmed_transactions).find(1).to_json(:include => :confirmed_transactions)
