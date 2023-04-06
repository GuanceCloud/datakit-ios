Pod::Spec.new do |s|

  s.name         = "FTMobileSDK"
  #s.version      = "1.3.11-alpha.1"
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
       c.osx.dependency 'FTMobileSDK/FTMacOSSupport'
   end
   
   s.subspec  'FTMobileAgent' do | agent |
       agent.ios.deployment_target = '10.0'
       agent.source_files =  'FTMobileSDK/FTMobileAgent/Core/*{.h,.m}','FTMobileSDK/FTMobileAgent/Config/*{.h,.m}'
       agent.dependency  'FTMobileSDK/FunctionModule'        

       agent.subspec 'AutoTrack' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/AutoTrack/**/*{.h,.m}','FTMobileSDK/FTMobileAgent/Logger/*{.h,.m,.c}'
       a.dependency 'FTMobileSDK/Common'
       a.dependency 'FTMobileSDK/FunctionModule/Protocol'
       a.dependency 'FTMobileSDK/FunctionModule/FTWKWebView'
       end


       agent.subspec 'ExternalData' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/ExternalData/*{.h,.m}'
       a.public_header_files = 'FTMobileSDK/FTMobileAgent/ExternalData/FTExternalDataManager.h'
       a.dependency 'FTMobileSDK/FunctionModule/Protocol'
       a.dependency 'FTMobileSDK/Common/Base'
       end

       agent.subspec 'ExtensionDataManager' do |e|
       e.source_files = 'FTMobileSDK/FTMobileAgent/Extension/*{.h,.m}'
       e.dependency 'FTMobileSDK/Common/Base'
       end

   end
    
    s.subspec 'FunctionModule' do |f|
       f.subspec 'FTRUM' do |r|
       r.source_files = 'FTMobileSDK/FTMobileAgent/FTRUM/RUMCore/**/*{.h,.m}','FTMobileSDK/FTMobileAgent/FTRUM/Monitor/*{.h,.m}','FTMobileSDK/FTMobileAgent/FTRUM/FTAppLaunchTracker.{h,m}'
       r.dependency 'FTMobileSDK/Common/Base'
       r.dependency 'FTMobileSDK/Common/Thread'
       r.dependency 'FTMobileSDK/FunctionModule/Protocol'
       end

       f.subspec 'FTWKWebView' do |j|
       j.source_files = 'FTMobileSDK/FTMobileAgent/FTWKWebView/**/*{.h,.m}'
       j.dependency 'FTMobileSDK/FunctionModule/Protocol'
       j.dependency 'FTMobileSDK/Common/Base'
       j.dependency 'FTMobileSDK/Common/Swizzle'
       end

       f.subspec 'URLSessionAutoInstrumentation' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/URLSessionAutoInstrumentation/**/*{.h,.m}'
       a.dependency 'FTMobileSDK/FunctionModule/Protocol'
       a.dependency 'FTMobileSDK/Common/Base'
       a.dependency 'FTMobileSDK/Common/Swizzle'
       end

       f.subspec 'Exception' do |e|
       e.source_files = 'FTMobileSDK/FTMobileAgent/Exception/*{.h,.m}'
       e.dependency 'FTMobileSDK/FunctionModule/Protocol'
       e.dependency 'FTMobileSDK/Common/Base'
       end

       f.subspec 'LongTask' do |a|
       a.source_files = 'FTMobileSDK/FTMobileAgent/LongTask/**/*{.h,.m}'
       a.dependency 'FTMobileSDK/Common'
       end

       f.subspec 'Protocol' do |r|
       r.source_files = 'FTMobileSDK/FTMobileAgent/Protocol/**/*{.h,.m}'
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
       e.source_files = 'FTMobileSDK/FTMobileExtension/*{.h,.m}','FTMobileSDK/FTMobileAgent/Config/*.{h,m}'
       e.dependency 'FTMobileSDK/FTMobileAgent/ExtensionDataManager'
       e.dependency 'FTMobileSDK/FunctionModule/FTRUM'
       e.dependency 'FTMobileSDK/FunctionModule/URLSessionAutoInstrumentation'
       e.dependency 'FTMobileSDK/FunctionModule/Exception'
       e.dependency 'FTMobileSDK/FTMobileAgent/ExternalData'
   end

   s.subspec 'FTMacOSSupport' do |m|
       m.source_files = 'FTMobileSDK/FTMobileAgent/Logger/*{.h,.m,.c}'
       m.dependency 'FTMobileSDK/Common'
       m.dependency  'FTMobileSDK/FunctionModule'        

   end
end


