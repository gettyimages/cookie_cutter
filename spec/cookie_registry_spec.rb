require 'rspec'
require 'cookie_cutter/base'
require 'cookie_cutter/cookie_registry'

describe CookieCutter::CookieRegistry do
  before do
    CookieCutter::CookieRegistry.instance.clear
    class MyCookie < CookieCutter::Base
      store_as 'my'
    end
    class MyOtherCookie < CookieCutter::Base
      store_as 'other'
    end
  end
  let :registered_cookies do
    CookieCutter::CookieRegistry.instance.all
  end
  it 'all cookies are registered' do
    registered_cookies.length.should == 2
    registered_cookies.should include(MyCookie)
    registered_cookies.should include(MyOtherCookie)
  end
end