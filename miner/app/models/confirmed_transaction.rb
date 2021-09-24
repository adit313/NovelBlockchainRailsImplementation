class ConfirmedTransaction < ApplicationRecord
  belongs_to :block

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
