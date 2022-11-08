Pod::Spec.new do |s|

  s.name         = "FTMobileExtension"
  s.version      = "1.0.0-alpha.1"
  s.summary      = "观测云 DataFlux iOS Extension 数据采集 SDK"
  s.description  = "观测云 DataFlux iOS Extension 数据采集 SDK"
  s.homepage     = "https://github.com/GuanceCloud/datakit-ios.git"

  s.license      = { type: 'Apache', :file => 'LICENSE'}
  s.authors             = { "hulilei" => "hulilei@jiagouyun.com","Brandon Zhang" => "zhangbo@jiagouyun.com" }
  # s.platform     = :ios, "8.0"
  s.default_subspec = 'Extension'

  s.ios.deployment_target = '9.0'
  s.source       = { :git => "https://github.com/GuanceCloud/datakit-ios.git", :tag => s.version }
  s.subspec 'Extension' do |e|
   e.source_files = 'FTMobileSDK/FTMobileExtension/*{.h,.m}','FTMobileSDK/FTMobileAgent/Extension/*{.h,.m}',
       'FTMobileSDK/FTMobileAgent/FTMobileConfig.{h,m}','FTMobileSDK/FTMobileAgent/FTMobileConfig+Private.h',
       'FTMobileSDK/FTMobileAgent/URLSessionAutoInstrumentation/**/*{.h,.m}','FTMobileSDK/FTMobileAgent/Exception/*{.h,.m}',
       'FTMobileSDK/FTMobileAgent/ExternalData/*{.h,.m}','FTMobileSDK/FTMobileAgent/FTRUM/**/*{.h,.m}','FTMobileSDK/FTMobileAgent/Protocol/**/*{.h,.m}',
       'FTMobileSDK/BaseUtils/Base/*{.h,.m}','FTMobileSDK/BaseUtils/Thread/*{.h,.m}','FTMobileSDK/BaseUtils/Swizzle/*{.h,.m,.c}'
    end
end


