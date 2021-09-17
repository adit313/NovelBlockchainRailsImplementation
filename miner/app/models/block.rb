class Block < ApplicationRecord
  has_many :confirmed_transactions
  validates :block_hash, uniqueness: true
  validates :block_hash, :solution_hash, :merkle_hash, :prev_block_hash, :nonce, :difficulty, presence: true
  validates :block_hash, length: { is: 64 }
  validates :merkle_hash, length: { is: 64 }
  validates :solution_hash, length: { is: 64 }
  validates :prev_block_hash, length: { is: 64 }

  def self.highest_block
    Block.calculate_block_height
    Block.order(block_height: :desc).first
  end

  def self.calculate_block_height
    Block.all.each { |block|
      if !block.block_height
        Block.find_height(block)
      end
    }
  end

  def self.find_height(block)
    prev_block = Block.find_by(block_hash: block.prev_block_hash)
    if prev_block.block_height
      block_height = prev_block.block_height + 1
      block.update(block_height: block_height)
      return block_height
    else
      block_height = Block.find_height(prev_block) + 1
      block.update(block_height: block_height)
      return block_height
    end
  end

  def self.received_newly_mined_block
    #add block to database
    #delete unconfirmed_transactions with the same hash from memory
  end
end
