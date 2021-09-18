Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/current_block", to: "block#current_block"

  get "/unconfirmed_transactions", to: "unconfirmed_transaction#all_unconfirmed_transaction"

  post "/new_transaction", to: "unconfirmed_transaction#new_transaction"

  post "/block", to: "block#new_block"
end
