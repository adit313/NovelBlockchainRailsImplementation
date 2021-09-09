class Block < ApplicationRecord
  has_many :confirmed_transactions

  def self.most_recent_block
    #return most recent block
  end
end
