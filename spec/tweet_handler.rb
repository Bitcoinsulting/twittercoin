require 'spec_helper'

# TODO: Occassionally clear VCR cache, and retest live
describe Tweet::Handler, :vcr do

  let(:sender) { "McTestor" }
  let(:status_id) { 2253000787 }

  context "Basic Handling:" do
    let(:content) { "@JimmyMcTester, keep it up! Here's a tip 0.01 BTC @tippercoin" }
    let(:info) {
      {
        recipient: "JimmyMcTester",
        amount: 1_000_000,
        sender: "McTestor"
      }
    }

    before(:each) do
      @handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)
    end

    it "should have content, sender" do
      expect(@handler.content).to eq(content)
      expect(@handler.sender).to eq(sender)
      expect(@handler.status_id).to eq(status_id)
    end

    it "should parse the tweet" do
      expect(@handler.parsed_tweet.info).to eq(info)
      expect(@handler.recipient).to eq('JimmyMcTester')
    end

    it "should have valid false by default" do
      expect(@handler.valid).to eq(false)
    end

    it "should, find/create sender_user and recipient_user" do
      expect(@handler.sender_user.screen_name).to eq(sender)
      expect(@handler.recipient_user.screen_name).to eq("JimmyMcTester")
    end

    it "should create a new bitcoin address for new recipients" do
      expect(@handler.recipient_user.addresses.first).to_not eq(nil)
    end

    it "should save the tweet in db regardless" do
      expect(TweetTip.count).to eq(0)
      expect(@handler.save_tweet_tip).to eq(true)
      expect(TweetTip.count).to eq(1)
      tweet_tip = TweetTip.last
      expect(tweet_tip.screen_name).to eq(sender)
      expect(tweet_tip.content).to eq(content)
    end

    # How to effectively test API?

    it "should push a transaction"

    it "should reply to recipient"

  end

  context "Check Validity" do

    it "should, if no account, build the error message" do
      User.create_profile("McTestor", authenticated: false)
      content = "@JimmyMcTester, 0.001 BTC, @tippercoin"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      handler.check_validity
      handler.reply_build
      expect(handler.valid).to eq(false)
      expect(handler.reply).to include("authenticate", "deposit", sender)
    end


    it "should, if 0 amount, build the error message" do
      content = "@JimmyMcTester, 0 BTC, @tippercoin"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      handler.check_validity
      handler.reply_build
      expect(handler.valid).to eq(false)
      expect(handler.reply).to include('tip', 'more', sender)
    end

    it "should, if direct tweet, build the error message" do
      content = "@tippercoin, 1 BTC, @otherdude"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      handler.check_validity
      handler.reply_build
      expect(handler.valid).to eq(false)
      expect(handler.reply).to include('someone', 'else', sender)
    end

    # TODO: Mock this!
    it "should, if not enough balance, build the error message" do
      content = "@JimmyMcTester, 1 BTC, @tippercoin"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      handler.check_validity
      handler.reply_build
      expect(handler.valid).to eq(false)
      expect(handler.reply).to include("top", "up")
    end

    it "should, otherwise, build a generic error message" do
      content = "Does this actually work @tippercoin"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      handler.check_validity
      handler.reply_build
      expect(handler.valid).to eq(false)
      expect(handler.reply).to include("not", "meant")
    end

    it "should build a valid recipient reply message" do
      content = "@JimmyMcTester, 0.001 BTC, @tippercoin"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      handler.check_validity
      expect(handler.valid).to eq(true)

      handler.reply_build
      expect(handler.reply).to include("@JimmyMcTester", "0.001", "tipped")
    end

    it "should not include reply_id in reply if invalid" do
      content = "@JimmyMcTester, failure, @tippercoin"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      expect(handler.status_id).to_not eq(nil)
      handler.check_validity
      expect(handler.state).to eq(:unknown)
      expect(handler.valid).to eq(false)

      handler.reply_build
      expect(handler.reply_id).to eq(nil)
    end

  end

  context "Edge Cases" do
    it "should search for screen_name regardless of casing" do
      # This is lowercase, twitter api actually return titleized
      content = "@mctestor, 0.0001 BTC @tippercoin"
      handler = Tweet::Handler.new(
        content: content,
        sender: sender,
        status_id: status_id)

      expect(handler.recipient_user).to_not eq(nil)
      expect(handler.recipient_user.screen_name).to eq("McTestor")
    end

    it "should not duplicate users when screen_names have different casing" do
      user = User.new(screen_name: "McTestor", api_user_id_str: "1")
      expect(user.save).to eq(true)
      user_lower = User.new(screen_name: "mctestor", api_user_id_str: "2")
      expect(user_lower.save).to eq(false)
    end

  end

  context "User Addresses" do

    it "should not find_profile is there is not address" do
      User.create({
        screen_name: sender,
        api_user_id_str: "321"
      })

      user = User.find_profile(sender)
      expect(user).to be(nil)
    end

    it "should create address for create_profile" do
      User.create_profile(sender)
      user = User.find_profile(sender)

      expect(user.screen_name).to eq(sender)
      expect(user.addresses.blank?).to eq(false)
    end

    it "should create address even if there is already a user" do
      user = User.create({
        screen_name: sender,
        api_user_id_str: "321"
      })

      expect(user.addresses.blank?).to eq(true)

      user = User.create_profile(sender)

      expect(user.addresses.blank?).to eq(false)

    end
  end

end
