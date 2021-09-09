class UnconfirmedTransaction < ApplicationRecord
  def self.verify_transaction(json)
    #check to see if transaction is valid
    #if valid add it to the mempool
    #and then propogate it to the network
  end

  def self.add_to_pool(transaction)
    #create and save this transaction object
  end

  def self.propogate_transation(transaction)
    #propogate the unconfirmed transaction to the mining network
  end
end
