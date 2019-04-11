Pod::Spec.new do |s|
  s.name         = 'antiFishhook'
  s.version      = '0.6.0'
  s.summary      = 'anti-fishhook'
  s.homepage     = 'https://github.com/TannerJin/anti-fishhook'
  s.license      = { :type => "MIT" }
  s.authors      = { "jintao" => "2802009591@qq.com" }
  s.source       = { :git => 'https://github.com/TannerJin/anti-fishhook.git', :tag => s.version }
  s.platform     = :ios, '9.0'
  s.source_files = "Source/*.swift"
  s.framework = "Foundation"
  s.requires_arc = true
end
