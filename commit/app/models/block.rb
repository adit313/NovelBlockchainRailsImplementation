class Block < ApplicationRecord
  has_many :confirmed_transactions

  def self.validate_new_mined_block
    #check to see if the block from the mining node is valid
    #if valid, perform the commit process
  end

  def self.validate_new_cleared_block
    #check to see if the block from the clearing node is valid
    #check to see if block is more cleared than current block and not closed
    #if yes, replace block
  end

  def self.commit_new_block
    #fail all waiting transactions in block at the end of it's window
    #write the commit hash for the recently cleared and closed block
    #use that commit hash and the solution hash of the newly mined block to write the block hash of the new block
    #append the new block with it's block hash to the chain with all transactions set to "waiting"
    #broadcast the new blocks to all networks
  end
end
