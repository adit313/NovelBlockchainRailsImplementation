class UnconfirmedTransaction < ApplicationRecord
  def self.verify_appended_transaction(json_input)
    #verify transaction is JSON
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

    #verify that the transaction has plain-text data,
    if !parse_input["destination"] || !parse_input["amount"] || !parse_input["nonce"]
      return "All transactions must have verifiable transaction details to be appended"
    end

    #Come back to this!!!!!
    #   verify it isn't already known in the unconfirmed transaction pool
    if UnconfirmedTransaction.find_by(transaction_hash: parse_input["transaction_hash"])
      return "All ready in memory, waiting to be appended"
    end

    #   verify the senders public key matches the address
    if Digest::SHA256.hexdigest(parse_input["sender_public_key"].to_s) != parse_input["sender"]
      return "Public key does not match sender's address"
    end

    #   verify the transaction hash, sender, nonce and information
    calculated_hash = Digest::SHA256.hexdigest(parse_input["amount"].to_s + parse_input["destination"].to_s + parse_input["nonce"].to_s + parse_input["sender"].to_s + parse_input["sender_public_key"].to_s + parse_input["txn_fee"].to_s)
    if calculated_hash != parse_input["transaction_hash"]
      return "The hash did not match the SHA256 hex Hash of (amount + destination + nonce + sender + sender_public_key + tx_fee)"
    end

    #verify it's signature
    digest = OpenSSL::Digest::SHA256.new
    begin
      pub_key = OpenSSL::PKey::RSA.new(parse_input["sender_public_key"].to_s)
    rescue
      return "Could not verify sender's public key"
    end

    if !pub_key.verify(digest, parse_input["sender_signature"].to_s, calculated_hash)
      return "Could not verify the signature with the public key, signatures must be the transaction hash signed by the associated private key"
    end

    #   see if it matches a transaction hash in an open block
    open_transactions = []
    Block.where(commit_hash: nil).each { |block|
      block.confirmed_transactions.each { |txn|
        open_transactions << txn
      }
    }

    #With the transaction verified, we now begin the clearing process
    referenced_confirmed_transaction = open_transactions.find_by(transaction_hash: parse_input["transaction_hash"])
    if referenced_confirmed_transaction
      #       if it does append the information and start to clear the transactions
      referenced_confirmed_transaction.update(amount: parse_input["amount"].to_f, destination: parse_input["destination"].to_s)
      #       verify funds, first we need to get the senders balance including already cleared transactions
      all_of_senders_uncommitted_transactions = open_transactions.find_by(sender: parse_input["sender"].to_s)
      all_of_senders_pay_to_transactions = open_transactions.find_by(destination: parse_input["sender"].to_s)

      account_details = Account.find_by(account_id: parse_input["sender"])
      if account_details && account_details.committed_balance
        sender_balance = account_details.committed_balance
      else
        sender_balance = 0
      end

      all_of_senders_pay_to_transactions.each { |open_txn|
        if open_txn.amount && status == "cleared"
          sender_balance += open_txn.amount
        end
      }
      #       send the block to the commit node network

    else
      return "Transaction was not found, it has been stored in temporary memory"
    end
    #   if it doesn't hold it in temporary memory and check for future matches

  end

  def self.verify_initiate_transaction(json_input)
    #verify transaction is JSON
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

    #it's a transaction that only has hash-data and sender information
    #   verify the transaction sender has authority
    #   verify the sender has enough fees to pay the gas and fail fee
    #   sign and forward the transaction to the mining network
  end
end
