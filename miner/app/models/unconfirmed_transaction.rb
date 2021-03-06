class UnconfirmedTransaction < ApplicationRecord
  def self.verify_transaction(parse_input)
    #check to see if transaction is valid
    # if json_input.is_a?(String)
    #   begin
    #     parse_input = JSON.parse(json_input)
    #   rescue
    #     return "JSON is not Valid"
    #   end
    # else
    #   return "Transaction inputed was not a JSON String"
    # end

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
    if Digest::SHA256.base64digest(parse_input["sender_public_key"].to_s) != parse_input["sender"]
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
    #if valid check to make sure it isn't in the mempool already or on chain
    mempool_transaction_test = UnconfirmedTransaction.find_by(transaction_hash: parse_input["transaction_hash"])
    if mempool_transaction_test
      return "Transaction is already known and staged in the mempool for inclusion in a new block"
    end

    nonce_transaction_test = UnconfirmedTransaction.find_by(sender: parse_input["sender"], nonce: parse_input["nonce"])
    if nonce_transaction_test
      return "Nonce has already been used in the mempool"
    end

    confirmed_transaction_test = ConfirmedTransaction.find_by(transaction_hash: parse_input["transaction_hash"])
    if confirmed_transaction_test
      return "Transaction is already on-chain"
    end

    #then add it to the mempool
    UnconfirmedTransaction.create(amount: parse_input["amount"],
                                  destination: parse_input["destination"],
                                  transaction_hash: parse_input["transaction_hash"],
                                  sender: parse_input["sender"],
                                  sender_public_key: parse_input["sender_public_key"],
                                  sender_signature: parse_input["sender_signature"],
                                  tx_fee: parse_input["tx_fee"],
                                  nonce: parse_input["nonce"])
    #and then propogate it to the network
    return "Transaction was accepted"
  end

  def self.propogate_transation(transaction)
    #propogate the unconfirmed transaction to the mining network
  end
end
