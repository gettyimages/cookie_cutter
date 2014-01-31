require 'rspec'
require 'cookie_cutter'
require 'cookie_cutter/test_support'
require 'active_support/core_ext'

class EmptyValuedCookie < CookieCutter::Base
end

class SingleValuedCookie < CookieCutter::Base
  store_as :svc
end

class MultiValuedCookie < CookieCutter::Base
  store_as :mvc

  has_attribute :value1
  has_attribute :value2, store_as: 'val2'
end

describe CookieCutter::Base do
  let(:cookie_jar) { CookieCutter::TestSupport::FakeCookieJar.new }
  it 'should not update the cookie_jar when no value is set' do
    SingleValuedCookie.new(cookie_jar)
    cookie_jar.to_hash.should be_empty
  end
  describe 'name' do
    it 'uses defined cookie name' do
      request = double('http_request', scheme: 'https', cookie_jar: cookie_jar)
      cookie = SingleValuedCookie.find(request)
      cookie.cookie_name.should == :svc
    end
    legacy_cookie = :getty_cookie
    let(:legacy_cookie_jar) { CookieCutter::TestSupport::FakeCookieJar.new({cookie_name: legacy_cookie}) }
    it 'uses cookie name in cookie_jar' do
      request = double('http_request', scheme: 'https', cookie_jar: legacy_cookie_jar)
      cookie = EmptyValuedCookie.find(request, {cookie_name: legacy_cookie})
      cookie.cookie_name.should == legacy_cookie
    end
    it 'should store the cookie with a lower-case name' do
      request = double('http_request', scheme: 'https', cookie_jar: cookie_jar)
      cookie = EmptyValuedCookie.find(request, {cookie_name: 'ABCabc1234'})
      cookie.cookie_name.should == 'abcabc1234'
    end
  end
  describe 'domain' do
    it 'does not set domain if not given' do
      class CookieWithNoDomain < CookieCutter::Base
        store_as :cwnd
      end
      cookie = CookieWithNoDomain.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwnd)[:domain].should be_nil
    end
    it 'uses given domain when saving cookie' do
      class CookieWithDomain < CookieCutter::Base
        store_as :cwd
        domain :all
      end
      cookie = CookieWithDomain.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwd)[:domain].should == :all
    end
  end
  describe 'lifetime' do
    it 'defaults to a session cookie' do
      class CookieWithNoLifetimeSpecified < CookieCutter::Base
        store_as :cwnls
      end
      cookie = CookieWithNoLifetimeSpecified.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwnls)[:expires].should be_nil
    end
    it 'sets expires to now plus lifetime' do
      now = Time.now
      lifetime = 60
      class CookieWithLifetimeSpecified < CookieCutter::Base
        store_as :cwls

        lifetime 60
      end
      cookie = CookieWithLifetimeSpecified.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwls)[:expires].should be_within(0.01).of(now + lifetime)
    end
    it 'sets expires to 20 years from now if made permanent!' do
      now = Time.now
      class PermanentCookie < CookieCutter::Base
        store_as :pc
        is_permanent
      end
      cookie = PermanentCookie.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:pc)[:expires].should be_within(0.01).of(20.years.from_now)
    end
  end
  describe 'secure_requests_only' do
    it 'defaults to all requests (insecure) cookie' do
      class CookieWithNoSecuritySpecified < CookieCutter::Base
        store_as :cwnss
      end
      cookie = CookieWithNoSecuritySpecified.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwnss)[:secure].should be_nil
    end
    it 'sets secure flag when secure_requests_only is specified' do
      class CookieWithSecureRequestsOnly < CookieCutter::Base
        store_as :cwsro
        secure_requests_only
      end
      options = { secure_request: true }
      cookie = CookieWithSecureRequestsOnly.new(cookie_jar, options)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwsro)[:secure].should be_true
    end

    it 'ignores secure_requests_only if set from non-secure url scheme' do
      class CookieWithSecureRequestsOnly < CookieCutter::Base
        store_as :cwsro
        secure_requests_only
      end
      options = { secure_request: false }
      cookie = CookieWithSecureRequestsOnly.new(cookie_jar, options)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwsro)[:secure].should be_nil
    end

  end
  describe 'http_only' do
    it 'defaults to being accessible to client scripts (i.e. not http_only)' do
      class ClassWithNoHttpOnly < CookieCutter::Base
        store_as :cwnho
      end
      cookie = ClassWithNoHttpOnly.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwnho)[:httponly].should be_nil
    end
    it 'sets httponly flag when http_only is specified' do
      class CookieWithHttpOnly < CookieCutter::Base
        store_as :cwho
        http_only
      end
      cookie = CookieWithHttpOnly.new(cookie_jar)
      cookie.value = "my value"
      cookie_jar.metadata_for(:cwho)[:httponly].should be_true
    end
  end
  describe 'delete!' do
    it 'should delete the cookie from the cookie jar' do
      cookie = SingleValuedCookie.new(cookie_jar)
      cookie.delete!
      cookie_jar.deleted?(cookie.cookie_name).should be_true
    end
  end
  describe 'single valued cookie' do
    let(:single_valued_cookie) { SingleValuedCookie.new(cookie_jar) }
    it 'should update the cookie jar when value is updated' do
      single_valued_cookie.value = "ordinary value"
      cookie_jar[:svc].should == "ordinary value"
    end
    it 'can be read via ordinary cookie jar' do
      single_value_cookie = SingleValuedCookie.new(CookieCutter::TestSupport::FakeCookieJar.new({ svc: "preset value" }))
      single_value_cookie.value.should == "preset value"
    end
  end
  describe 'multi-valued cookie' do
    let(:multi_valued_cookie) { MultiValuedCookie.new(cookie_jar) }
    it 'should update the cookie jar when an attribute is updated' do
      multi_valued_cookie.value1 = "myval"
      cookie_jar[:mvc][:value1].should == "myval"
    end
    it 'generates getters and setters for each attribute' do
      multi_valued_cookie.value1 = "myval1"
      multi_valued_cookie.value2 = "myval2"

      multi_valued_cookie.value1.should == "myval1"
      multi_valued_cookie.value2.should == "myval2"
    end
    it "privatizes the singular 'value' getter and setter" do
      expect { multi_valued_cookie.value = "myval"}.to raise_error(NoMethodError)
      expect { multi_valued_cookie.value }.to raise_error(NoMethodError)
    end
    it "can override stored attribute name with :store_as option" do
      multi_valued_cookie.value2 = "myval2"
      cookie_jar[:mvc][:val2].should == "myval2"
    end
    describe 'attribute metadata' do
      it "should provide attributes array" do
        MultiValuedCookie.attributes.length.should == 2
      end
      it "should provide each attribute name" do
        MultiValuedCookie.attributes.find{|a| a.name == :value1}.should_not be_nil
        MultiValuedCookie.attributes.find{|a| a.name == :value2}.should_not be_nil
      end
      it "should provide each attribute storage key as a symbol" do
        MultiValuedCookie.attributes.find{|a| a.name == :value1}.storage_key.should == :value1
        MultiValuedCookie.attributes.find{|a| a.name == :value2}.storage_key.should == :val2
      end
    end
  end
end