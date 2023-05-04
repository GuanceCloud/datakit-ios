Pod::Spec.new do |s|

  s.name         = "FTMobileSDK"
  #s.version      = "1.3.9-alpha.4"
  s.version      = "$JENKINS_DYNAMIC_VERSION"
  s.summary      = "观测云 DataFlux iOS 数据采集 SDK"
  s.description  = "观测云 DataFlux iOS 数据采集 SDK"
  s.homepage     = "https://github.com/GuanceCloud/datakit-ios.git"

  s.license      = { type: 'Apache', :file => 'LICENSE'}
  s.authors             = { "hulilei" => "hulilei@jiagouyun.com","Brandon Zhang" => "zhangbo@jiagouyun.com" }
  # s.platform     = :ios, "8.0"
  s.default_subspec = 'Core'

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.13'
  # s.watchos.deployment_target = "2.0"
  # s.tvos.deployment_target = "9.0"

#   s.source       = { :http => "https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTAutoTrack/.zip" }
   s.source       = { :git => "https://github.com/GuanceCloud/datakit-ios.git", :tag => "$JENKINS_DYNAMIC_VERSION" }
   
   s.subspec  'Core' do | c |
       c.ios.dependency 'FTMobileSDK/FTMobileAgent'
       c.osx.dependency 'FTMobileSDK/Common'
   end
   
   s.subspec  'FTMobileAgent' do | agent |
       core_dir = 'FTMobileSDK/FTMobileAgent/'
       agent.ios.deployment_target = '10.0'
       agent.source_files = 'FTMobileSDK/FTMobileAgent/Core/*{.h,.m}'

       agent.subspec 'FTRUM' do |r|
       r.source_files = 'FTMobileSDK/FTMobileAgent/FTRUM/RUMCore/**/*{.h,.m}','FTMobileSDK/FTMobileAgent/FTRUM/Monitor/*{.h,.m}'
       r.dependency 'FTMobileSDK/Common/Base'
       r.dependency 'FTMobileSDK/Common/Thread'
       r.dependency 'FTMobileSDK/FTMobileAgent/Protocol'
       end

       agent.subspec 'Protocol' do |r|
       r.source_files = 'FTMobileSDK/FTMobileAgent/Protocol/**/*{.h,.m}'
       end

       agent.subspec 'JSBridge' do |j|
       j.source_files = 'FTMobileSDK/FTMobileAgent/JSBridge/*{.h,.m}'
       j.dependency 'FTMobileSDK/Common/Base'
       end

       agent.subspec 'AutoTrack' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/AutoTrack/**/*{.h,.m}','FTMobileSDK/FTMobileAgent/Logger/*{.h,.m,.c}'
       a.dependency 'FTMobileSDK/Common'
       a.dependency 'FTMobileSDK/FTMobileAgent/Protocol'
       a.dependency 'FTMobileSDK/FTMobileAgent/JSBridge'
       end

       agent.subspec 'LongTask' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/LongTask/**/*{.h,.m}'
       a.dependency 'FTMobileSDK/Common'
       end

       agent.subspec 'ExternalData' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/ExternalData/*{.h,.m}'
       a.public_header_files = 'FTMobileSDK/FTMobileAgent/ExternalData/FTExternalDataManager.h'
       a.dependency 'FTMobileSDK/FTMobileAgent/Protocol'
       a.dependency 'FTMobileSDK/Common/Base'
       end

       agent.subspec 'URLSessionAutoInstrumentation' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/URLSessionAutoInstrumentation/**/*{.h,.m}'
       a.dependency 'FTMobileSDK/FTMobileAgent/Protocol'
       a.dependency 'FTMobileSDK/Common/Base'
       a.dependency 'FTMobileSDK/Common/Swizzle'
       end

       agent.subspec 'ExtensionDataManager' do |e|
       e.source_files = 'FTMobileSDK/FTMobileAgent/Extension/*{.h,.m}'
       e.dependency 'FTMobileSDK/Common/Base'
       end

       agent.subspec 'Exception' do |e|
       e.source_files = 'FTMobileSDK/FTMobileAgent/Exception/*{.h,.m}'
       e.dependency 'FTMobileSDK/FTMobileAgent/Protocol'
       e.dependency 'FTMobileSDK/Common/Base'
       end
   end
   

   s.subspec 'Common' do |c|

       c.subspec 'Base' do |cc|
       cc.source_files = 'FTMobileSDK/BaseUtils/Base/*{.h,.m}'

       end

       c.subspec 'Thread' do |cc|
       cc.source_files = 'FTMobileSDK/BaseUtils/Thread/*{.h,.m}'
       end

       c.subspec 'Network' do |cc|
       cc.source_files =  'FTMobileSDK/BaseUtils/Network/*{.h,.m}'
       cc.dependency 'FTMobileSDK/Common/Thread'
       cc.dependency 'FTMobileSDK/Common/FTDataBase'
       end

       c.subspec 'FTDataBase' do |cc|
       cc.source_files =  'FTMobileSDK/BaseUtils/FTDataBase/**/*{.h,.m}'
       cc.dependency 'FTMobileSDK/Common/Base'
       end

       c.subspec 'Swizzle' do |cc|
       cc.source_files = 'FTMobileSDK/BaseUtils/Swizzle/*{.h,.m,.c}'
       cc.dependency 'FTMobileSDK/Common/Base'
       end

   end

    s.subspec 'Extension' do |e|
       e.platform = :ios, '10.0'
       e.ios.deployment_target = '10.0'
       e.source_files = 'FTMobileSDK/FTMobileExtension/*{.h,.m}'
       e.dependency 'FTMobileSDK/FTMobileAgent/ExtensionDataManager'
       e.dependency 'FTMobileSDK/FTMobileAgent/FTRUM'
       e.dependency 'FTMobileSDK/FTMobileAgent/URLSessionAutoInstrumentation'
       e.dependency 'FTMobileSDK/FTMobileAgent/Exception'
       e.dependency 'FTMobileSDK/FTMobileAgent/ExternalData'
   end
end


