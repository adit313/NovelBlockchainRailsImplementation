class MainController < ApplicationController
  def current_block #get current highest block
    block_id = Block.highest_block.id
    result = Block.includes(:confirmed_transactions).find(block_id).to_json(:include => :confirmed_transactions)
    render json: result
  end

  def mine_next_block
    Mine.mine_next_block
  end

  def unconfirmed_transactions
    if params[:id]
      skip_id = params[:id]
    else
      skip_id = 0
    end
    result = UnconfirmedTransaction.offset(skip_id).limit(50)
    render json: result.to_json
  end

  def all_unconfirmed_transactions
    result = UnconfirmedTransaction.all
    render json: result.to_json
  end

  def new_transaction
    submitted_input = JSON.parse(request.body.read)
    result = []
    if submitted_input.class == Array
      submitted_input.each { |transaction|
        result << UnconfirmedTransaction.verify_transaction(transaction)
      }
    else
      result << UnconfirmedTransaction.verify_transaction(submitted_input)
    end
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
