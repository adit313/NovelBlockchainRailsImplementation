require "net/http"

class ConfirmedTransaction < ApplicationRecord
  belongs_to :block
  validates :transaction_hash, :sender, :sender_public_key, :sender_signature, :nonce, :block_id, :transaction_index, presence: true

  def self.validate_new_transaction(json_input)
    #check for transaction formatting
    #perform generic validation tests
    test = ConfirmedTransaction.generic_transaction_check(json_input)
    if test
      return test
    end
    parse_input = JSON.parse(json_input)
    #   see if it matches a transaction hash in temporary memory TO-DO

    #   otherwise check the sender's balance and if sufficient, route it to the miner
    sender_account = Account.update_single_account_balances(parse_input["sender"])
    if !sender_account
      return "sender account could not be located in the blockchain"
    end

    if parse_input["nonce"].to_i <= sender_account.highest_nonce
      return "Invalid nonce, all transactions must be in increasing nonce order"
    end

    tx_fee_withholding = parse_input["tx_fee"].to_f
    #If transaction has a destination and amount details, you won't need to withhold a potential penalty for not disclosing
    withholding_required = parse_input["destination"] && parse_input["amount"] ? tx_fee_withholding : (tx_fee_withholding + PENALTY_WITHHOLDING_REQUIRED)

    if !sender_account.confirmed_balance || sender_account.confirmed_balance < withholding_required
      return "The user doesn't have enough balance to initiate this transaction"
    end

    if ConfirmedTransaction.find_by(transaction_hash: parse_input["transaction_hash"])
      return "Transaction hash has already been added to the network"
    end

    #otherwise transaction is valid and good to BROADCAST to other commit nodes/mining nodes
    result = broadcast_transaction_to_other_commit_and_mining_nodes(json_input)
    return result
  end

  def self.broadcast_transaction_to_other_commit_and_mining_nodes(json_input)
    #Broadcast POST "/new_transaction" to commit nodes
    # Net::HTTP.post(URI("http://other_commit_node_addresses/append_information"), payload, "Content-Type" => "application/json")

    #Broadcast POST "/new_transaction" to mining.stardust.finance
    response = Net::HTTP.post(URI("https://mining.stardust.finance/new_transaction"), json_input, "Content-Type" => "application/json")
    return response.body
  end

  def self.verify_and_append_transaction(json_input)

    #perform generic validation tests
    test = ConfirmedTransaction.generic_transaction_check(json_input)
    if test
      return test
    end

    parse_input = JSON.parse(json_input)

    #verify that the transaction has plain-text data,
    if !parse_input["destination"] || !parse_input["amount"] || !parse_input["nonce"]
      return "All append requests must have verifiable transaction details to be appended"
    end

    #verify that the transaction amount is greater than 0,
    if parse_input["amount"].to_f < 0
      return "All transactions must have a positive amount "
    end

    #   verify the transaction hash, sender, nonce and information
    calculated_hash = Digest::SHA256.hexdigest(parse_input["amount"].to_s + parse_input["destination"].to_s + parse_input["nonce"].to_i.to_s + parse_input["sender"].to_s + parse_input["sender_public_key"].to_s + parse_input["tx_fee"].to_s)
    if calculated_hash != parse_input["transaction_hash"]
      return "The hash did not match the SHA256 hex Hash of (amount + destination + nonce + sender + sender_public_key + tx_fee)"
    end

    #   see if it matches a transaction hash in an open block
    open_transactions = []
    Block.where(commit_hash: nil).each { |block|
      block.confirmed_transactions.each { |txn|
        open_transactions << txn
      }
    }

    #find that transaction to see if it's already been appended
    referenced_confirmed_transaction = open_transactions.detect { |e| e.transaction_hash == parse_input["transaction_hash"] }
    if referenced_confirmed_transaction
      if !referenced_confirmed_transaction.destination || !referenced_confirmed_transaction.amount || !referenced_confirmed_transaction.nonce
        referenced_confirmed_transaction.update(destination: parse_input["destination"], amount: parse_input["amount"], nonce: parse_input["nonce"])
        #BROADCAST to other commit nodes/clearing nodes
        result = broadcast_transaction_to_other_commit_and_clearing_nodes(json_input)
        return result
      end
    else
      return "Transaction was not found on this commit nodes chain"
    end
  end

  def self.broadcast_transaction_to_other_commit_and_clearing_nodes(json_input)
    #POST "/append_information" to other commit nodes
    # Net::HTTP.post(URI("http://other_commit_node_addresses/append_information"), payload, "Content-Type" => "application/json")

    #POST "/append_information" to clearing.stardust.finance
    response = Net::HTTP.post(URI("https://clearing.stardust.finance/append_information"), json_input, "Content-Type" => "application/json")
    return response.body
  end

  def self.generic_transaction_check(json_input)
    if json_input.is_a?(String)
      begin
        parse_input = JSON.parse(json_input)
      rescue
        return "JSON is not Valid"
      end
    else
      return "Transaction inputed was not a JSON String"
    end

    if !parse_input["transaction_hash"] || parse_input["transaction_hash"].length != 64
      return "All transactions must have a valid SHA256 transaction hash"
    end

    if !parse_input["tx_fee"]
      return "Transaction Fee is a required field"
    end

    if parse_input["tx_fee"].to_f.to_s != parse_input["tx_fee"].to_s
      return "Transaction Fee must be numeric"
    end

    if !parse_input["sender"] || !parse_input["sender_public_key"] || !parse_input["sender_signature"]
      return "All transactions must have a valid sender and attached signature"
    end

    #   verify the senders public key matches the address
    if (Digest::SHA256.base64digest(parse_input["sender_public_key"].to_s) != parse_input["sender"])
      return "Public key does not match sender's address"
    end

    #verify it's signature
    digest = OpenSSL::Digest::SHA256.new
    begin
      pub_key = OpenSSL::PKey::RSA.new(parse_input["sender_public_key"].to_s)
    rescue
      return "Could not verify sender's public key"
    end

    if !pub_key.verify(digest, [parse_input["sender_signature"]].pack("H*"), parse_input["transaction_hash"].to_s)
      return "Could not verify the signature with the public key, signatures must be the transaction hash signed by the associated private key"
    end
  end

  def self.coinbase_transaction_check(json_input)
    if json_input.is_a?(String)
      begin
        parse_input = JSON.parse(json_input)
      rescue
        return "JSON is not Valid"
      end
    else
      return "Transaction inputed was not a JSON String"
    end

    if !parse_input["transaction_hash"] || parse_input["transaction_hash"].length != 64
      return "All transactions must have a valid SHA256 transaction hash"
    end

    if !parse_input["sender"] || !parse_input["sender_public_key"] || !parse_input["sender_signature"]
      return "All transactions must have a valid sender and attached signature"
    end

    if !parse_input["tx_fee"]
      return "Transaction fee is a required field"
    end

    if parse_input["tx_fee"].to_f.to_s != parse_input["tx_fee"].to_s
      return "Transaction fee must be numeric"
    end

    #   verify the senders public key matches the address
    if parse_input["sender"] != "0000000000000000000000000000000000000000000="
      return "Coinbase transaction must have an all 0 sender address"
    end

    #verify it's signature
    digest = OpenSSL::Digest::SHA256.new
    begin
      pub_key = OpenSSL::PKey::RSA.new(parse_input["sender_public_key"].to_s)
    rescue
      return "Could not verify sender's public key"
    end

    if !pub_key.verify(digest, [parse_input["sender_signature"]].pack("H*"), parse_input["transaction_hash"].to_s)
      return "Could not verify the signature with the public key, signatures must be the transaction hash signed by the associated private key"
    end
  end
end
