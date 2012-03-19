module FatZebra
	module Models
		class Refund < Base
			attribute :amount, :reference, :transaction_id, :original_transaction_id

			def original_transaction
				@original_transaction ||= Purchase.find(self.original_transaction_id)
			end
		end
	end
end