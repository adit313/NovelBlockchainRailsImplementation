Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/current_highest_block", to: "main#current_highest_block"

  get "/account/:id", to: "main#account"

  get "/get_chain/:id", to: "main#get_chain"

  get "/get_chain", to: "main#get_chain"

  post "/new_transaction", to: "main#new_transaction"

  post "/append_information", to: "main#append_information"

  post "/block", to: "main#new_block"

  post "/commit", to: "main#commit"

  post "/cleared_block", to: "main#cleared_block"
end
