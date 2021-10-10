require "net/http"

class ConfirmedTransaction < ApplicationRecord
  belongs_to :block

  #CHECK CODE TO CHANGE NONCE TO SIGNED NONCE
  def self.verify_and_append_transaction(json_input)
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

    if !parse_input["tx_fee"]
      return "Transaction Fee is a required field"
    end

    if parse_input["tx_fee"].to_f.to_s != parse_input["tx_fee"].to_s
      return "Transaction Fee must be numeric"
    end

    if !parse_input["sender"] || !parse_input["sender_public_key"] || !parse_input["sender_signature"]
      return "All transactions must have a valid sender and attached signature"
    end

    #verify that the transaction has plain-text data,
    if !parse_input["destination"] || !parse_input["amount"] || !parse_input["nonce"]
      return "All transactions must have verifiable transaction details to be appended"
    end

    #verify that the transaction amount is greater than 0,
    if parse_input["amount"] < 0
      return "All transactions must have a positive amount "
    end

    #Come back to this!!!!!
    #   verify it isn't already known in the temporary transaction pool
    #   to_ implement later

    #   verify the senders public key matches the address
    if Digest::SHA256.base64digest(parse_input["sender_public_key"].to_s) != parse_input["sender"]
      return "Public key does not match sender's address"
    end

    #   verify the transaction hash, sender, nonce and information
    calculated_hash = Digest::SHA256.hexdigest(parse_input["amount"].to_s + parse_input["destination"].to_s + parse_input["nonce"].to_i.to_s + parse_input["sender"].to_s + parse_input["sender_public_key"].to_s + parse_input["tx_fee"].to_s)
    if calculated_hash != parse_input["transaction_hash"]
      return "The hash did not match the SHA256 hex Hash of (amount + destination + signed nonce + sender + sender_public_key + tx_fee)"
    end

    #verify it's signature
    digest = OpenSSL::Digest::SHA256.new
    begin
      pub_key = OpenSSL::PKey::RSA.new(parse_input["sender_public_key"].to_s)
    rescue
      return "Could not verify sender's public key"
    end

    if !pub_key.verify(digest, [parse_input["sender_signature"]].pack("H*"), calculated_hash)
      return "Could not verify the signature with the public key, signatures must be the transaction hash signed by the associated private key"
    end

    #   see if it matches a transaction hash in an open block
    open_transactions = []
    Block.calculate_block_height
    blocks_to_check = Block.order(block_height: :desc).limit(CLEARING_WINDOW)
    blocks_to_check.where(commit_hash: nil).each { |block|
      block.confirmed_transactions.each { |txn|
        open_transactions << txn
      }
    }

    #With the transaction verified, we now begin the clearing process
    referenced_confirmed_transaction = open_transactions.detect { |e| e.transaction_hash == parse_input["transaction_hash"] }
    if referenced_confirmed_transaction
      #       if it does append the information and start to clear the transactions
      referenced_confirmed_transaction.update(amount: parse_input["amount"].to_f, destination: parse_input["destination"].to_s)
      #       now we clear the transactions using this recursive function
      ConfirmedTransaction.clear_transactions(open_transactions, parse_input["sender"].to_s)
      #       send these blocks to the commit node network
      transmit_open_blocks(blocks_to_check)
      #       TRANSMIT BLOCK CODE
      return "Transaction was matched"
    else
      #   if it doesn't hold it in temporary memory and check for future matches
      #   ADD UNMATCHED TRANSACTION STORAGE
      return "Transaction was not found, it has been stored in temporary memory"
    end
  end

  def self.transmit_open_blocks(blocks)
    payload = blocks.includes(:confirmed_transactions).to_json(:include => :confirmed_transactions)
    #POST "/cleared_block" to commit.stardust.finance
    Net::HTTP.post(URI("http://commit.stardust.finance/cleared_block"), payload, "Content-Type" => "application/json")
  end

  def self.clear_transactions(open_transactions, sender)
    all_of_senders_uncommitted_transactions = open_transactions.select { |e| e.sender == sender }
    all_of_senders_pay_to_transactions = open_transactions.select { |e| e.sender == sender }

    account_details = Account.find_by(account_id: sender)

    highest_nonce = account_details.highest_nonce + 1

    if account_details && account_details.confirmed_balance
      sender_balance = account_details.confirmed_balance
    else
      sender_balance = 0
    end

    all_of_senders_pay_to_transactions.each { |open_txn|
      if open_txn.amount && open_txn.status == "pre-cleared"
        sender_balance += open_txn.amount
      end
    }

    all_of_senders_uncommitted_transactions.each { |open_txn|
      sender_balance -= open_txn.tx_fee
    }

    destinations = []

    if all_of_senders_uncommitted_transactions
      all_of_senders_uncommitted_transactions.sort { |e| e.nonce }.each { |open_txn|
        # smart contract execution here if destination is routed to a smart contract. TO-DO
        if open_txn.nonce <= highest_nonce
          open_txn.update(status: "illegal nonce")
        else
          if open_txn.amount && sender_balance > open_txn.amount
            open_txn.update(status: "pre-cleared")
            destinations << open_txn.destination
          else
            open_txn.update(status: "insufficient funds")
          end
        end
        highest_nonce += 1
      }
    end

    if destinations.length >= 1
      destinations.uniq!.each { |destination|
        if destination != sender
          ConfirmedTransaction.clear_transactions(open_transactions, destination)
        end
      }
    end
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

    if !parse_input["sender"] || !parse_input["sender_public_key"] || !parse_input["sender_signature"]
      return "All transactions must have a valid sender and attached signature"
    end

    if !parse_input["tx_fee"]
      return "Transaction Fee is a required field"
    end

    if parse_input["tx_fee"].to_f.to_s != parse_input["tx_fee"].to_s
      return "Transaction Fee must be numeric"
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
    if parse_input["sender"] != "0000000000000000000000000000000000000000000000000000000000000000"
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
