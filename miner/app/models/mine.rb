class Mine < ApplicationRecord
  def self.mine_next_block
    #check to see if there are transactions
    #if there are, select which ones to incorporate into a new block
    #add up fees and append coinbase transation with all fees using miner public address key
    #calculate merkle hash
    #calclate solution hash
    #on successful calculation, sign block and submit to commit node network
  end
end
