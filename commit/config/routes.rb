Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/current_highest_block", to: "block#current_highest_block"

  get "/balance", to: "account#balance"

  get "/nonce", to: "account#nonce"

  post "/new_transaction", to: "confirmed_transaction#new_transaction"

  post "/append_transaction", to: "confirmed_transaction#append_transaction"

  post "/block", to: "block#new_block"

  post "/commit", to: "block#commit"

  post "/clear_block", to: "block#new_clear"
end
