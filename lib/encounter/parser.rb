module Encounter
  # parser for html pages
  # @private
  module HTMLParser
    def self.included(base)
      base.extend Encounter::ParserClassMethods
    end

    # Running all methods from {.define_parser_list}
    #
    # @param obj [Nokogiri::CSS::Node] Nokigiri object
    #
    # @return [Hash] all parsed attributes
    def parse_all(obj)
      return {} unless respond_to? :parser_list
      raise 'parser_list must be Array' unless parser_list.is_a? Array

      result = {}
      parser_list.each do |k|
        raise "Unknown method #{k}" unless respond_to? k, true
        result.merge! send(k, obj)
      end
      result
    end

    # Parse standard text attributes.
    # List of attributes is given in _PARSER_OBJECTS_ constant.
    # Every attribute should have next fields:
    #
    # * <b>id</b> - CSS selector of HTML element
    # * <b>attr</b> - attribute name
    #
    # Possible additional fields are:
    #
    # * <b>type</b> - '_f_' for Float or '_i_' for Integer
    # * <b>proc</b> - <b>_Proc_</b> object to be executed over result
    #
    # @param obj [Nokogiri::CSS::Node] Nokigiri object
    # @return [Hash] all parsed attributes
    def parse_attributes(obj)
      Hash[
        self.class::PARSER_OBJECTS.map do |o|
          res = obj.css(o[:id]).map(&:text).join
          res = ParserConvertors.send("to_#{o[:type]}", res) if o[:type]
          res = o[:proc].call(res) if o[:proc]
          [o[:attr], res]
        end
      ]
    end

    # Return object ID from URL. Supported objects are
    # {Encounter::Player}, {Encounter::Game} and {Encounter::Team}
    def parse_url_id(url)
      url.match(/[gtu]id=(\d+)/).captures.first.to_i
    end

    # Return Encounter object from URL. Supported objects are
    # {Encounter::Player}and {Encounter::Team}
    #
    # @param obj [String]
    # @return [Encounter::Player] if giver URL links to player
    # @return [Encounter::Team] if giver URL links to team
    def parse_url_object(obj)
      c = obj['href'].match(/([gtu])id=(\d+)/).captures
      case c.first
      when 't'
        Encounter::Team.new(@conn, tid: c.last.to_i, name: obj.text)
      when 'u'
        Encounter::Player.new(@conn, uid: c.last.to_i, name: obj.text)
      else
        raise 'Unsupported link type'
      end
    end

    # Find page number for paginated lists
    #
    # @param obj [Nokogiri::CSS::Node] Nokigiri object
    # @param suffix [String] Suffix, contained in URL to select only needed URLs
    #
    # @return [Integer]
    def parse_max_page(obj, suffix)
      obj.css('a').select { |a| a['href'] =~ /#{suffix}.*page=\d+$/ }
         .map { |a| a['href'].match(/page=(\d+)$/).captures.first.to_i }.max
    end

    # Convert array of two elements to hash with _id_ and _name_ keys.
    #
    # @param pair [Array]
    # @return [Hash]
    def parse_id_name(pair)
      { id: pair.first.to_i, name: pair.last.strip }
    end

    # Parse document with semicolon-separated id-name records.
    #
    # @param url [String] URL of list
    # @param params [Hash] URL parameters
    # @param proc [Proc] Procedure for value postprocessing
    #
    # @return [Hash]
    def parse_cvs_pair(url, params, proc)
      @conn.page_get(url, params).each_line.map do |r|
        r = r.split(';')
        proc.call(r) if r.size == 2 && r.first =~ /\d+/
      end.compact
    end

    # Returns Nokogiri object for URL
    #
    # @param url [String] URL
    # @param params [Hash] URL parameters
    #
    # @return [Nokogiri::CSS::Node]
    def load_page(url, params = {})
      Nokogiri::HTML(@conn.page_get(url, params))
    end
  end

  # @private
  # class method for parser
  module ParserClassMethods
    def define_parser_list(*items)
      define_method(:parser_list) do
        items.map do |item|
          raise ArgumentError, 'Want symbol parameters' unless item.is_a? Symbol
          item
        end
      end
    end
  end

  # @private
  # Module holding conversions for parsed strings to numeric types
  module ParserConvertors
    # @param v [String]
    # @return [Float] Result of conversion
    def to_f(v)
      v.tr(',', '.').gsub(/[^0-9\.]/, '').to_f
    end

    # @param v [String]
    # @return [Integer] Result of conversion
    def to_i(v)
      v.gsub(/\D/, '').to_i
    end

    module_function :to_f, :to_i
  end
end
