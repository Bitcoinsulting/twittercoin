class User < ActiveRecord::Base

  # Similar to a "Followings table"
  has_many :tips_received, class_name: "TweetTip", foreign_key: "recipient_id"
  has_many :tips_given, class_name: "TweetTip", foreign_key: "sender_id"

  has_many :addresses

  validates :screen_name, uniqueness: { case_sensitive: false }, presence: true

  def self.unauthenticated
    where(authenticated: false)
  end

  def self.unauthenticated_with_tips
    unauthenticated.joins(:tips_received).where.not(
      tweet_tips: { tx_hash: nil, satoshis: nil }
    ).group('users.id').having('COUNT(tweet_tips.id) > 0')
  end

  def reminded_recently?(less_than: 3.days)
    reminded_at && reminded_at > less_than.ago
  end

  def all_tips
    (tips_received.is_valid + tips_given.is_valid).sort_by(&:created_at).reverse
  end

  def self.find_profile(screen_name)
    joins(:addresses).find_by('screen_name ILIKE ?', screen_name)
  end

  def self.create_profile(screen_name)
    return unless screen_name
    user = User.find_or_create_by(screen_name: screen_name)
    user.slug ||= SecureRandom.hex(8)

    user.save

    user.addresses.create(BitcoinAPI.generate_address)
    user
  end

  def current_address
    addresses.last.address
  end

  def get_balance
    info = BitcoinAPI.get_info(current_address)
    info["final_balance"]
  end

  def likely_missing_fee?(amount)
    difference = get_balance - amount.to_i
    difference >= 0 && difference < FEE
  end

  def enough_balance?(amount)
    amount ? get_balance >= amount + FEE : false
  end

  def enough_confirmed_unspents?(amount)
    begin
      BitcoinAPI.get_unspents(current_address, amount + FEE)
      true
    rescue Exception => e
      ap e.inspect
      false
    end
  end

  def withdraw(amount, to_address)
    BitcoinAPI.send_tx(addresses.last, to_address, amount)
    true
  end

end
