class MainController < ApplicationController
  def current_block #get current highest block
    block_id = Block.highest_block.id
    result = Block.includes(:confirmed_transactions).find(block_id).to_json(:include => :confirmed_transactions)
    render json: result
  end

  def unconfirmed_transactions
    if params[:id]
      skip_id = params[:id]
    else
      skip_id = 0
    end
    result = UnconfirmedTransaction.offset(skip_id).limit(50)
    render json: result
    Mine.mine_next_block
  end

  def new_transaction
    submitted_multiblock = JSON.parse(request.body.read)
    result = []
    if submitted_multiblock.class == Array
      submitted_multiblock.each { |block|
        result << UnconfirmedTransaction.verify_transaction(request.body.read)
      }
    else
      result << UnconfirmedTransaction.verify_transaction(request.body.read)
    end
    render json: result
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
    render json: result
  end
end
