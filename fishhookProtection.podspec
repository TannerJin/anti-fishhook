Pod::Spec.new do |s|
  s.name         = 'fishhookProtection'
  s.version      = '0.3.0'
  s.summary      = 'protection your project for fishhook'
  s.homepage     = 'https://github.com/Jintao1997/fishhook_prt'
  s.license      = { :type => "MIT" }
  s.authors      = { "jintao" => "2802009591@qq.com" }
  s.source       = { :git => 'https://github.com/Jintao1997/fishhook_prt.git', :tag => s.version }
  s.platform     = :ios, '9.0'
  s.source_files = "Source/*.swift"
  s.framework = "Foundation"
  s.requires_arc = true
end
