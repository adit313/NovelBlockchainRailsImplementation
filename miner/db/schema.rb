# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_09_09_015647) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blocks", force: :cascade do |t|
    t.string "block_hash"
    t.string "commit_hash"
    t.string "merkle_hash"
    t.string "solution_hash"
    t.string "prev_block_hash"
    t.integer "nonce"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "confirmed_transactions", force: :cascade do |t|
    t.float "amount"
    t.string "destination"
    t.string "transaction_hash"
    t.string "sender"
    t.string "sender_public_key"
    t.string "sender_signiture"
    t.float "tx_fee"
    t.string "status"
    t.integer "nonce"
    t.bigint "block_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["block_id"], name: "index_confirmed_transactions_on_block_id"
  end

  create_table "unconfirmed_transactions", force: :cascade do |t|
    t.string "transaction_hash"
    t.string "sender"
    t.string "sender_public_key"
    t.string "sender_signiture"
    t.float "tx_fee"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "confirmed_transactions", "blocks"
end
