require 'cookie_cutter/cookie_attribute'
require 'cookie_cutter/cookie_registry'

module CookieCutter
  module Cookie
    module ClassMethods
      def find(request, options={})
        options[:secure_request] = request.scheme == 'https' unless options[:secure_request]
        new(request.cookie_jar, options)
      end

      attr_reader :cookie_name

      def store_as(name)
        @cookie_name = name
        CookieRegistry.instance.register self
      end

      attr_reader :cookie_domain

      def domain(domain_value)
        @cookie_domain = domain_value
        add_handler do |cookie|
          cookie[:domain] = domain_value
        end
      end

      attr_reader :cookie_lifetime

      def lifetime(seconds)
        @cookie_lifetime = seconds
        add_handler do |cookie|
          cookie[:expires] = (Time.now + seconds)
        end
      end

      def is_permanent
        twenty_years = 60 * 60 * 24 * 365.25 * 20
        lifetime twenty_years
      end

      def secure_requests_only
        @secure = true
        add_handler do |cookie|
          if cookie[:secure_request]
            cookie[:secure] = true
          end
        end
      end

      def secure?
        @secure ? true : false
      end

      def multi_valued
        @multi_valued = true
      end

      def multi_valued?
        @multi_valued || attributes.any?
      end

      def http_only
        @http_only = true
        add_handler do |cookie|
          cookie[:httponly] = true
        end
      end

      alias_method :httponly, :http_only

      def http_only?
        @http_only ? true : false
      end

      alias_method :httponly?, :http_only?

      def has_attribute(attribute_name, options={})
        raise "CookieCutter value names must by symbols. #{attribute_name} is not a symbol" unless attribute_name.is_a?(Symbol)
        #make value and value= private when the cookie has one or more named values
        private :value, :value=, :set_value

        attribute = CookieAttribute.new(attribute_name, options)
        send :define_method, attribute_name do
          get_attribute_value(attribute.storage_key)
        end
        setter_method_name = "#{attribute_name.to_s}=".to_sym
        send :define_method, setter_method_name do |value|
          set_attribute_value(attribute.storage_key, value)
        end
        attributes << attribute
      end

      def add_options(cookie)
        handlers.each do |handler|
          handler.call(cookie)
        end
      end

      def add_handler(&block)
        handlers << block
      end

      def handlers
        @handlers ||= []
      end

      def attributes
        @attributes ||= []
      end
    end

    def self.included(klass)
      klass.extend ClassMethods
    end

    def initialize(cookie_jar, options={})
      @cookie_jar = cookie_jar
      @secure_request = options[:secure_request]
      @cookie_name = (options[:cookie_name] || self.class.cookie_name).downcase
    end

    def secure_request?
      @secure_request.nil? ? true : @secure_request
    end

    def value
      value = @cookie_jar[cookie_name]
      #if the value is a hash, we need to dup it so that we are not manipulating the original instance
      #we need to do this because a rails cookie_jar hangs onto the original reference in order to detect value changes
      value = value.dup if value.is_a?(Hash)
      value
    end

    def value=(val)
      cookie = {value: val, secure_request: secure_request?}
      self.class.add_options(cookie)
      @cookie_jar[cookie_name] = cookie
    end

    def delete!
      options = {}
      self.class.add_options(options)
      @cookie_jar.delete(cookie_name, options)
    end

    def cookie_name
      @cookie_name
    end

    def secure?
      self.class.secure?
    end

    def cookie_lifetime
      self.class.cookie_lifetime
    end

    def cookie_domain
      self.class.cookie_domain
    end

    alias_method :set_value, :value=

    private
    def set_attribute_value(value_name, val)
      values_hash = value() || {}
      values_hash[value_name] = val
      set_value(values_hash)
    end

    def get_attribute_value(value_name)
      values_hash = value() || {}
      values_hash[value_name]
    end
  end
end