Pod::Spec.new do |s|

  s.name         = "FTMobileSDK"
#   s.version      = "1.0.2-alpha.8"
  s.version      = "$JENKINS_DYNAMIC_VERSION"
  s.summary      = "驻云 DataFlux iOS 数据采集 SDK"
  s.description  = "驻云 DataFlux iOS 数据采集 SDK"
  s.homepage     = "https://github.com/DataFlux-cn/datakit-ios.git"

  s.license      = { type: 'Apache', :file => 'LICENSE'}
  s.authors             = { "hulilei" => "hulilei@jiagouyun.com","Brandon Zhang" => "zhangbo@jiagouyun.com" }
  # s.platform     = :ios, "8.0"
  s.default_subspec = 'Core'

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  # s.watchos.deployment_target = "2.0"
  # s.tvos.deployment_target = "9.0"

#   s.source       = { :http => "https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTAutoTrack/.zip" }
   s.source       = { :git => "https://github.com/DataFlux-cn/datakit-ios.git", :tag => "$JENKINS_DYNAMIC_VERSION" }
   
   s.subspec  'Core' do | c |
       c.ios.dependency 'FTMobileSDK/FTMobileAgent'
       c.osx.dependency 'FTMobileSDK/Common'
   end
   
   s.subspec  'FTMobileAgent' do | agent |
       agent.ios.deployment_target = '9.0'
       agent.source_files = 'FTMobileSDK/FTMobileAgent/**/*'
       agent.library = "resolv.9"
       agent.dependency 'FTMobileSDK/Common'
   end

   s.subspec 'Common' do |common|
       common.source_files = 'FTMobileSDK/BaseUtils/**/*'
   end
   

end
