class OpenBlock < ApplicationRecord
  has_many :open_transactions, dependent: :destroy

  #function to close a block
  def close
    txn_hash_w_status = []
    #fail all of the open transactions
    self.open_transactions.sort_by { |k| k.transaction_index }.each { |open_txn|
      if open_txn.status == "waiting"
        open_txn.update(status: "failed")
        #SHA256 all the transactions along with their statuses
        txn_hash_w_status << Digest::SHA256.hexdigest((open_txn.amount ? open_txn.amount.to_s : "") + (open_txn.destination ? open_txn.destination.to_s : "") + open_txn.nonce.to_s + open_txn.sender.to_s + open_txn.sender_public_key.to_s + open_txn.status.to_s + open_txn.tx_fee.to_s)
      end
    }
    commit_hash = Block.compute_transaction_merkle_tree(txn_hash_w_status)
    self.update(commit_hash: commit_hash)
  end
end
