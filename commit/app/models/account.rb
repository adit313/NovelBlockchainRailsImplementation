class Account < ApplicationRecord
  def self.update_all_account_balances
    accounts = ConfirmedTransaction.pluck(destination).uniq!
    accounts.each { |account|
      received_money = ConfirmedTransaction.where(status: "cleared", destination: account).sum(:amount)
      highest_nonce = 0
      sum = 0
      spent_money = ConfirmedTransaction.where(status: "cleared", sender: account).each { |txn|
        sum += txn.amount
        sum += txn.tx_fee
        highest_nonce = txn.nonce if txn_nonce > highest_nonce
      }
      account_object = Account.find_or_create_by(account_id: account)
      account_object.update(confirmed_balance: (received_money.to_f - spent_money.to_f), highest_nonce: highest_nonce)
    }
  end

  def self.update_single_account_balances(account_address)
    received_money_transactions = ConfirmedTransaction.where(status: "cleared", destination: account_address)

    if received_money_transactions.count == 0
      return nil
    else
      received_money = received_money_transactions.sum(:amount)
    end

    highest_nonce = 0
    spent_money = 0
    ConfirmedTransaction.where(status: "cleared", sender: account_address).each { |txn|
      sum += txn.amount
      sum += txn.tx_fee
      highest_nonce = txn.nonce if txn_nonce > highest_nonce
    }
    account_object = Account.find_or_create_by(account_id: account_address)
    account_object.update(confirmed_balance: (received_money.to_f - spent_money.to_f), highest_nonce: highest_nonce)
    return account_object
  end

  def self.update_balances_in_new_block(accounts)
    accounts.each { |account|
      received_money = ConfirmedTransaction.where(status: "cleared", destination: account).sum(:amount)
      highest_nonce = 0
      sum = 0
      spent_money = ConfirmedTransaction.where(status: "cleared", sender: account).each { |txn|
        sum += txn.amount
        sum += txn.tx_fee
        highest_nonce = txn.nonce if txn_nonce > highest_nonce
      }
      account_object = Account.find_or_create_by(account_id: account)
      account_object.update(confirmed_balance: (received_money.to_f - spent_money.to_f), highest_nonce: highest_nonce)
    }
  end
end
