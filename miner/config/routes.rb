Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/current_block", to: "main#current_block"

  get "/unconfirmed_transactions/:id", to: "main#unconfirmed_transactions"

  post "/new_transaction", to: "main#new_transaction"

  post "/block", to: "main#block"
end
