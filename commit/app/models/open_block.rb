class OpenBlock < ApplicationRecord
  has_many :open_transactions, dependent: :destroy

  #function to close a block
  def close
    txn_hash_w_status = []
    #fail all of the open transactions
    self.open_transactions.order(:transaction_index).each { |open_txn|
      if open_txn.status == "waiting"
        open_txn.update(status: "failed")
      end
      if open_txn.status == "pre-cleared"
        open_txn.update(status: "cleared")
      end
      #SHA256 all the transactions along with their statuses
      txn_hash_w_status << Digest::SHA256.hexdigest((open_txn.amount ? open_txn.amount.to_f.to_s : "") + (open_txn.destination ? open_txn.destination.to_s : "") + open_txn.nonce.to_s + open_txn.sender.to_s + open_txn.sender_public_key.to_s + open_txn.status.to_s + open_txn.tx_fee.to_f.to_s)
    }
    commit_hash = Block.compute_transaction_merkle_tree(txn_hash_w_status)
    return commit_hash
  end
end
