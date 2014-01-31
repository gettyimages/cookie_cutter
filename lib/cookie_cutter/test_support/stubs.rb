require 'cookie_cutter/test_support/fake_cookie_jar'

module CookieCutter
  module TestSupport
    module Stubs
      module Finders
        def find(request, options={})
          new(TestSupport::FakeCookieJar.find, options)
        end
      end
      
      def stub_all
        TestSupport::FakeCookieJar.empty!
        CookieCutter::Base::class_eval do
          extend Finders
        end
      end
    end
  end
end