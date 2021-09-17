MAX_BLOCK_TRANSACTIONS = 10.freeze
BLOCK_DIFFICULTY = 1 #defined as the number of hexadecimal zeros at the begining of the hash
COMMIT_NODE_KEY = OpenSSL::PKey.read File.read "storage/private_key.pem"
COMMIT_NODE_ADDRESS = Digest::SHA256.base64digest(COMMIT_NODE_KEY.public_key.to_s)
PENALTY_WITHHOLDING_REQUIRED = 1
CLEARING_WINDOW = 2
