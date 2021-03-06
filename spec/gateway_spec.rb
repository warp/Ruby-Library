require 'spec_helper'

TEST_USER = "TEST"
TEST_TOKEN = "TEST"
TEST_LOCAL = ENV["TEST_LOCAL"] == "true" || false

describe FatZebra::Gateway do
	let(:valid_card) { "5123456789012346" }
	let(:valid_expiry) { 1.year.from_now.strftime("%m/%Y") }
	
	before :each do
		# Setup the gateway for testing
		server = TEST_LOCAL == true ? "fatapi.dev" : "gateway.sandbox.fatzebra.com.au"
		FatZebra.configure do
			username TEST_USER
			token TEST_TOKEN
			sandbox true
			test_mode true
			gateway server
			options :secure => !TEST_LOCAL, :silence => true # Silence keeps the warnings quiet for testing (deprecation warnings)
		end
		@gw = FatZebra.gateway
	end

	it "should require username and token are provided" do
		lambda { FatZebra::Gateway.new("test", nil) }.should raise_exception(FatZebra::InvalidArgumentError)
	end

	it "should require that the gateway_server arg is not nil or empty" do
		lambda { FatZebra::Gateway.new("test", "test", "") }.should raise_exception(FatZebra::InvalidArgumentError)	
	end

	it "should load a valid instance of the gateway" do
		@gw.ping.should be_true
	end

	it "should perform a purchase" do
		result = FatZebra::Models::Purchase.create(10000, {:card_holder => "Matthew Savage", :number => valid_card, :expiry => valid_expiry, :cvv => 123}, "TEST#{rand}", "1.2.3.4")
		result.should be_successful
		result.errors.should be_empty
	end

	it "should fetch a purchase" do
		result = FatZebra::Models::Purchase.create(10000, {:card_holder => "Matthew Savage", :number => valid_card, :expiry => valid_expiry, :cvv => 123}, "TES#{rand}T", "1.2.3.4")
		purchase = FatZebra::Models::Purchase.find(:id => result.purchase.id)
		purchase.id.should == result.purchase.id
	end

	it "should fetch a purchase via reference" do
		ref = "TES#{rand}T"
		result = FatZebra::Models::Purchase.create(10000, {:card_holder => "Matthew Savage", :number => valid_card, :expiry => valid_expiry, :cvv => 123}, ref, "1.2.3.4")

		purchases = FatZebra::Models::Purchase.find(:reference => ref)
		purchases.id.should == result.purchase.id
	end

	# it "should fetch purchases within a date range" do
	# 	start = Time.now
	# 	5.times do |i|
	# 		@gw.purchase(10000, {:card_holder => "Matthew Savage", :card_number => valid_card, :card_expiry => valid_expiry, :cvv => 123}, "TEST#{rand(1000)}-#{i}", "1.2.3.4")
	# 	end

	# 	purchases = @gw.purchases(:from => start - 300, :to => Time.now + 300)
	# 	purchases.count.should >= 5
	# end

	it "should fetch purchases with a from date" do
		start = Time.now
		5.times do |i|
			FatZebra::Models::Purchase.create(10000, {:card_holder => "Matthew Savage", :number => valid_card, :expiry => valid_expiry, :cvv => 123}, "TEST#{rand(1000)}-#{i}", "1.2.3.4")
		end

		purchases = FatZebra::Models::Purchase.find(:from => start)
		purchases.count.should >= 5
	end

	it "should refund a transaction" do
		purchase = FatZebra::Models::Purchase.create(10000, {:card_holder => "Matthew Savage", :number => valid_card, :expiry => valid_expiry, :cvv => 123}, "TES#{rand}T", "1.2.3.4")
		result = FatZebra::Models::Refund.create(purchase.result.id, 100, "REFUND-#{purchase.result.id}")

		result.should be_successful
		result.result.successful.should be_true
	end

	it "should tokenize a card" do
		response = @gw.tokenize("M Smith", "5123456789012346", valid_expiry, "123")
		response.should be_successful
		response.result.token.should_not be_nil
	end

	# it "should fetch a tokenized card" do
	# 	token = @gw.tokenize("M Smith", "5123456789012346", valid_expiry, "123").result.token
	# 	card_response = @gw.tokenized_card(token)

	# 	card_response.should be_successful
	# 	card_response.result.token.should == token
	# 	card_response.result.card_number.should == "512345XXXXXX2346"
	# end

	# it "should fetch all cards" do
	# 	cards = @gw.tokenized_cards

	# 	cards.first.should be_instance_of(FatZebra::Models::Card)
	# end

	it "should perform a purchase with a tokenized card" do
		token = @gw.tokenize("M Smith", "5123456789012346", valid_expiry, "123").result.token
		purchase = @gw.purchase(10000, {:token => token}, "TEST#{rand}}", "127.0.0.1")

		purchase.should be_successful
		purchase.result.successful.should be_true
	end

	it "should transact in USD" do
		result = FatZebra::Models::Purchase.create(10000, {:card_holder => "Matthew Savage", :number => valid_card, :expiry => valid_expiry, :cvv => 123}, "TEST#{rand}", "1.2.3.4", 'USD')
		result.should be_successful, result.raw
		result.errors.should be_empty
		result.result.currency.should == 'USD'
	end
end