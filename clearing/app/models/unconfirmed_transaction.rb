class UnconfirmedTransaction < ApplicationRecord
  def self.verify_transaction
    #if it's a transaction that has plain-text data,
    #   verify it isn't already known
    #   verify it's transaction hash, sender, nonce and information
    #   see if it matches a transaction hash in an open block
    #       if it does append the information and clear the transaction,
    #       verify funds, run smart contracts and update the global state
    #       send the block to the commit node network
    #   if it doesn't hold it in temporary memory and check for future matches

    #if it's a transaction that only has hash-data and sender information
    #   verify the transaction sender has authority
    #   verify the sender has enough fees to pay the gas and fail fee
    #   sign and forward the transaction to the mining network
  end
end
