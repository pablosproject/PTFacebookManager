Pod::Spec.new do |s|
  s.name         = "PTFacebookmanager"
  s.version      = "0.9"
  s.summary      = "Simple wrapper around Facebook SDK 3.5"
  s.homepage     = "https://github.com/pablosproject/PTFacebookManager"
  s.license      = 'MIT'
  s.author       = { "Paolo Tagliani" => "pablosproject@gmail.com" }
  s.platform     = :ios, '5.0'
  s.source       = { :git => "https://github.com/pablosproject/PTFacebookManager", :tag => "0.9" }
  s.source_files  = 'PTTTFacebookmanager/PTFacebookManager/*.{h,m}'
  s.requires_arc = true
  s.dependency 'Facebook-iOS-SDK', '>= 3.5'
end
