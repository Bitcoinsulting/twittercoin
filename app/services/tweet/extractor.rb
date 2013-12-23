module Tweet::Extractor
  module Mentions
    extend self

    # Accept: String
    # Returns: Array or Strings, or nil
    def parse(content)
      usernames = content.scan(/@(\w+)/).flatten
      return [nil] if usernames.blank?
      return usernames
    end

  end

  module Amounts
    extend self

    ### Supported Currency Symbols:
    ### Order matters, higher means more priority
    SYMBOLS = [
      {
        name: :mBTC_SUFFIX,
        regex: /\s(\d*.?\d*)\s?mBTC/i,
        satoshify: Proc.new {|n| (n.to_f * SATOSHIS / MILLIBIT).to_i }
      },
      {
        name: :mBTC_PREFIX,
        regex: /mBTC\s?(\d*.?\d*)/i,
        satoshify: Proc.new {|n| (n.to_f * SATOSHIS / MILLIBIT).to_i }
      },
      {
        name: :BTC_SUFFIX,
        regex: /\s(\d*.?\d*)\s?BTC/i,
        satoshify: Proc.new {|n| (n.to_f * SATOSHIS).to_i}
      },
      {
        name: :bitcoin_SUFFIX,
        regex: /\s(\d*.?\d*)\s?bitcoin/i,
        satoshify: Proc.new {|n| (n.to_f * SATOSHIS).to_i}
      },
      {
        name: :BTC_SIGN,
        regex: /฿\s?(\d*.?\d*)/i,
        satoshify: Proc.new {|n| (n.to_f * SATOSHIS).to_i}
      },
      {
        name: :BTC_PREFIX,
        regex: /BTC\s?(\d*.?\d*)/i,
        satoshify: Proc.new {|n| (n.to_f * SATOSHIS).to_i}
      },
      {
        name: :USD,
        regex: /\s(\d*.?\d*)\s?USD/i,
        satoshify: Proc.new {|n| (n.to_f / Mtgox.latest * SATOSHIS).to_i }
      },
      {
        name: :dollar,
        regex: /\s(\d*.?\d*)\s?dollar/i,
        satoshify: Proc.new {|n| (n.to_f / Mtgox.latest * SATOSHIS).to_i }
      },
      {
        name: :USD_SIGN,
        regex: /\$\s?(\d*.?\d*)/i,
        satoshify: Proc.new {|n| (n.to_f / Mtgox.latest * SATOSHIS).to_i }
      },
      {
        name: :beer,
        regex: /\s(\d*.?\d*)\s?beer/i,
        satoshify: Proc.new {|n| (n.to_f * 4 / Mtgox.latest * SATOSHIS).to_i }
      },
      {
        name: :internet,
        regex: /\s(\d*.?\d*)\s?internet/i,
        satoshify: Proc.new {|n| (n.to_f * 1.337 / Mtgox.latest * SATOSHIS).to_i }
      }
    ]

    # Accept: String
    # Returns: Array of Integers, or nil
    def parse(content)

      # Parse all and loop until first symbol is valid
      # See order at top
      parse_all(content).each do |p|
        values = p.values.flatten
        return values if !values.empty?
      end

      # Return nil if nothing is found
      return [nil]
    end

    # Accept: String
    # Returns: Array of hashes, hash has key and array
    def parse_all(content)
      SYMBOLS.map do |sym|
        raw = content.scan(sym[:regex]).flatten
        {
          sym[:name] => raw.map do |r|
            sym[:satoshify].call(r) if r.is_number?
          end.compact
        }
      end
    end

  end
end
