Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/current_block", to: "main#current_block"

  get "/unconfirmed_transactions", to: "main#all_unconfirmed_transactions"

  get "/unconfirmed_transactions/:id", to: "main#unconfirmed_transactions"

  get "/mine", to: "main#mine_next_block"

  post "/new_transaction", to: "main#new_transaction"

  post "/block", to: "main#block"
end
