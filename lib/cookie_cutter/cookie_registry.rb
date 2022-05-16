require 'singleton'

module CookieCutter
  class CookieRegistry
    include Singleton

    def initialize
      @cookies = {}
    end

    def register(cookie_class)
      @cookies[cookie_class.cookie_name] = cookie_class
    end

    def all
      @cookies.values
    end

    def clear
      @cookies.clear
    end
  end
end
