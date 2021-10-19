class Account < ApplicationRecord
  def self.update_single_account_balances(account)
    received_money_transactions = ConfirmedTransaction.where(status: "cleared", destination: account)
    pre_cleared_transactions = OpenTransaction.where(status: "pre-cleared", destination: account)

    if received_money_transactions.count + pre_cleared_transactions.count == 0
      return nil
    else
      received_money = received_money_transactions.sum(:amount)
      pre_cleared_money = pre_cleared_transactions.sum(:amount)
    end

    highest_nonce = 0
    spent_money = 0

    ConfirmedTransaction.where(sender: account).each { |txn|
      spent_money += txn.amount if txn.status == "cleared"
      spent_money += txn.tx_fee if txn.status == "cleared"
      highest_nonce = txn.nonce if txn.nonce > highest_nonce
    }

    OpenTransaction.where(sender: account).each { |txn|
      spent_money += txn.amount if txn.status == "pre-cleared"
      spent_money += txn.tx_fee if txn.status == "pre-cleared"
      highest_nonce = txn.nonce if txn.nonce > highest_nonce
    }

    account_object = Account.find_or_create_by(account_id: account)

    account_object.update(confirmed_balance: (received_money.to_f + pre_cleared_money.to_f - spent_money.to_f), highest_nonce: highest_nonce)
    return account_object
  end

  def self.update_all_account_balances
    accounts = ConfirmedTransaction.pluck(:destination).uniq
    accounts.each { |account|
      Account.update_single_account_balances(account)
    }
  end

  def self.update_balances_in_new_block(accounts)
    accounts.each { |account|
      Account.update_single_account_balances(account)
    }
  end
end
