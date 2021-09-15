class Block < ApplicationRecord
  has_many :confirmed_transactions

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
    #if valid, perform the commit process
    Block.commit_new_block(parse_input)
  end

  def self.validate_new_cleared_block(json_input)
    #check to see if the block from the clearing node is valid
    #check to see if block is more cleared than current block and not closed
    #conflict resolution
    #if yes, replace block
  end

  def self.commit_new_block(parse_input)
    #get the block that needs to be closed
    replace_block = Block.where(commit_hash: nil).sort(:block_height).first

    #get open block that has transactions appended from memory
    open_block = OpenBlock.find_by(block_hash: replace_block.block_hash)

    #close the open_block
    open_block.close

    #update all the transaction
    temp_open_transactions = open_block.open_transactions.order(:transaction_index)
    replace_block.confirmed_transactions.order(:transaction_index).each_with_index { |txn_to_replace, index|
      replacement_transaction = temp_open_transactions[index]
      txn_to_replace.update(replacement_transaction.attributes)
    }

    #Now that the block has updated transactions in it, we write the commit hash
    replace_block.update(commit_hash: open_block.commit_hash)

    #We now use that commit hash and the solution hash of the newly mined block to write the block hash of the new block
    new_block_hash = Digest::SHA256.hexdigest(open_block.commit_hash + parse_input["solution_hash"])
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
    #delete the temporary block in memory
    open_block.destroy

    #broadcast the new blocks to all networks
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
      return "All transactions must have a valid merkle_hash"
    end

    if !parse_input["solution_hash"] || parse_input["solution_hash"].length != 64
      return "All transactions must have a valid solution hash"
    end

    if !parse_input["prev_block_hash"] || parse_input["prev_block_hash"].length != 64
      return "All transactions must have a valid previous block hash"
    end

    if !parse_input["nonce"] || parse_input["nonce"].to_i <= 0
      return "All transactions must have a valid nonce"
    end

    if !parse_input["difficulty"] || parse_input["difficulty"].to_i <= 0
      return "All transactions must have a valid difficulty"
    end

    calculated_hash = Digest::SHA256.hexdigest(parse_input["nonce"].to_s + parse_input["merkle_hash"].to_s + parse_input["prev_block_hash"].to_s)

    if calculated_hash != parse_input["solution_hash"]
      return "The hash did not match the SHA256 hex hash of (merkle_hash + nonce + prev_block_hash)"
    end

    starting_zeros = ("0" * parse_input["difficulty"].to_i)
    if !hash.start_with?(starting_zeros)
      return "The solution hash did not satisfy the difficulty function"
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
    block_transactions = parse_input["transactions"]
    if block_transactions.class != Array
      return "Transactions were not properly formatted as an array"
    end
    block_transactions.each { |txn|
      txn_test = ConfirmedTransaction.generic_transaction_check(txn.to_json)
      if txn_test
        return txn_test
      end

      if !txn["transaction_index"]
        return "All transactions must have an index"
      end
    }
  end

  def merkle_check(json_input)
    parse_input = JSON.parse(json_input)
    block_transactions = parse_input["transactions"]
    if block_transactions.class != Array
      return "Transactions were not properly formatted as an array"
    end
    hashes = []
    block_transactions.sort_by { |k| k["transaction_index"] }.each { |txn|
      hashes << txn["transaction_hash"]
    }
    return Block.compute_transaction_merkle_tree(hashes)
  end
end
