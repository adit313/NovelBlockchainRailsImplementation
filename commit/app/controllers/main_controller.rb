class MainController < ApplicationController
  def current_block #get current highest block
    block_id = Block.highest_block.id
    result = Block.includes(:confirmed_transactions).find(block_id).to_json(:include => :confirmed_transactions)
    render json: result
  end

  def new_transaction
    result = ConfirmedTransaction.validate_new_transaction(request.body.read)
    render json: result
  end

  def account
    account = Account.find_by(account_id: CGI.unescape(params[:id]))
    render json: account.to_json
  end

  def append_information
    result = ConfirmedTransaction.verify_and_append_transaction(request.body.read)
    if !result
      result = "Your information was accepted and relayed to the clearing network"
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

  def commit
    result = Block.validate_new_mined_block(request.body.read)
    render json: result.to_json
  end

  def cleared_block
    submitted_multiblock = JSON.parse(request.body.read)
    result = []
    if submitted_multiblock.class == Array
      submitted_multiblock.each { |block|
        result << Block.validate_new_cleared_block(block.to_json)
      }
    else
      result << Block.validate_new_cleared_block(request.body.read)
    end
    render json: result.to_json
  end

  def get_chain
    if params[:id]
      result = Block.includes(:confirmed_transactions).where(block_height: (params[:id].to_i)..((params[:id].to_i + 50))).to_json(:include => :confirmed_transactions)
    else
      result = Block.includes(:confirmed_transactions).order(block_height: :desc).limit(50).to_json(:include => :confirmed_transactions)
    end
    render json: result
  end

  def closed_block
    block_id = Block.where.not(commit_hash: nil).order(block_height: :desc).first.id
    result = Block.includes(:confirmed_transactions).find(block_id).to_json(:include => :confirmed_transactions)
    render json: result
  end

  def open_block
    result = OpenBlock.includes(:open_transactions).order(id: :desc).limit(50).to_json(:include => :open_transactions)
    render json: result
  end
end
