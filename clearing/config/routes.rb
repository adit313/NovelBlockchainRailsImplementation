Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get "/current_block", to: "block#current_block"

  get "/current_chain", to: "block#all_open_blocks"

  post "/appended_information", to: "confirmed_transaction#append"

  post "/block", to: "block#new_block"
end
