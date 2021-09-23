class MainController < ApplicationController
  def current_block #get current highest block
    block_id = Block.highest_block.id
    result = Block.includes(:confirmed_transactions).find(block_id).to_json(:include => :confirmed_transactions)
    render json: result.to_json
  end

  def get_chain
    result = Block.includes(:confirmed_transactions).where(block_height: (params[:id].to_i)..((params[:id].to_i + 50))).to_json(:include => :confirmed_transactions)
    render json: result.to_json
  end

  def open_blocks
    result = Block.includes(:confirmed_transactions).where(commit_hash: nil).to_json(:include => :confirmed_transactions)
    render json: result.to_json
  end

  def open_transactions
    open_blocks = Block.where(commit_hash: nil)
    open_transactions = []
    open_blocks.each { |block|
      block.confirmed_transactions.each { |txn|
        if !txn.amount || !txn.destination
          open_transactions << txn
        end
      }
    }
    render json: open_transactions.to_json
  end

  def append_information
    result = ConfirmedTransaction.verify_and_append_transaction(request.body.read)
    render json: result.to_json
  end

  def block
    submitted_multiblock = JSON.parse(request.body.read)
    result = []
    if submitted_multiblock.class == Array
      submitted_multiblock.each { |block|
        result << Block.validate_newly_received_block(block.to_json)
      }
    else
      result << Block.validate_newly_received_block(request.body.read)
    end
    render json: result.to_json
  end
end
