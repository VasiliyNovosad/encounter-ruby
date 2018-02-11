module Encounter
  # parser for html pages
  # @private
  module HTMLParser
    def self.included(base)
      base.extend Encounter::ParserClassMethods
    end

    # Running all methods from {.define_parser_list}
    #
    # @param object [Nokogiri::CSS::Node] Nokigiri object
    #
    # @return [Hash]
    def parse_all(object)
      return {} unless respond_to? :parser_list
      raise 'parser_list must be Array' unless parser_list.is_a? Array

      result = {}
      parser_list.each do |k|
        raise "Unknown method #{k}" unless respond_to? k, true
        result.merge! send(k, object)
      end
      result
    end

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

    def parse_url_id(url)
      url.match(/[gtu]id=(\d+)/).captures.first.to_i
    end

    def parse_url_object(url)
      c = url['href'].match(/([gtu])id=(\d+)/).captures
      case c.first
      when 't'
        Encounter::Team.new(@conn, tid: c.last.to_i, name: url.text)
      when 'u'
        Encounter::Player.new(@conn, uid: c.last.to_i, name: url.text)
      else
        raise 'Unsupported link type'
      end
    end
  end

  # class method for parser
  # @private
  module ParserClassMethods
    def define_parser_list(*items)
      list = []
      items.each do |item|
        raise ArgumentError, 'Want symbol parameters' unless item.is_a? Symbol
        list << item
      end
      define_method(:parser_list) do
        list.freeze
      end
    end
  end

  # @private
  module ParserConvertors
    def to_f(v)
      v.tr(',', '.').gsub(/[^0-9\.]/, '').to_f
    end

    def to_i(v)
      v.gsub(/\D/, '').to_i
    end

    module_function :to_f, :to_i
  end
end
