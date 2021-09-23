Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/current_block", to: "main#current_block"

  get "/get_chain/:id", to: "main#get_chain"

  get "/open_blocks", to: "main#open_blocks"

  get "/open_transactions", to: "main#open_transactions"

  post "/append_information", to: "main#append_information"

  post "/block", to: "main#block"
end
