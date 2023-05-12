Pod::Spec.new do |s|

	s.name         = "FTMobileSDK"
	#s.version      = "1.3.12-alpha.3"
	s.version      = "$JENKINS_DYNAMIC_VERSION"
	s.summary      = "观测云 iOS 数据采集 SDK"
	#s.description  = ""
	s.homepage     = "https://github.com/GuanceCloud/datakit-ios.git"

	s.license      = { type: 'Apache', :file => 'LICENSE'}
	s.authors             = { "hulilei" => "hulilei@jiagouyun.com","Brandon Zhang" => "zhangbo@jiagouyun.com" }
	s.default_subspec = 'FTMobileAgent'

	s.ios.deployment_target = '10.0'
	s.osx.deployment_target = '10.13'
	s.source       = { :git => "https://github.com/GuanceCloud/datakit-ios.git", :tag => "#{s.version}" }


	s.subspec  'FTMobileAgent' do | agent |
		agent.platform = :ios, '10.0'

		agent.source_files =  'FTMobileSDK/FTMobileAgent/**/*{.h,.m}'
		agent.dependency  'FTMobileSDK/FTSDKCore'

	end

	s.subspec 'Extension' do |e|
		e.platform = :ios, '10.0'
		e.source_files = 'FTMobileSDK/FTMobileExtension/*{.h,.m}','FTMobileSDK/FTMobileAgent/Config/*.{h,m}','FTMobileSDK/FTMobileAgent/ExternalData/*{.h,.m}','FTMobileSDK/FTMobileAgent/Extension/*{.h,.m}'
		e.dependency 'FTMobileSDK/FTSDKCore/FTRUM'
		e.dependency 'FTMobileSDK/FTSDKCore/URLSessionAutoInstrumentation'
		e.dependency 'FTMobileSDK/FTSDKCore/Exception'
	end


	s.subspec 'FTSDKCore' do |c|
		c.ios.deployment_target = '10.0'
		c.osx.deployment_target = '10.13'
		c.subspec 'FTRUM' do |r|
			core_path='FTMobileSDK/FTSDKCore/FTRUM/'
			r.source_files = core_path+'RUMCore/**/*{.h,.m}',core_path+'Monitor/*{.h,.m}',core_path+'FTAppLaunchTracker.{h,m}'
			r.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Base'
			r.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Thread'
			r.dependency 'FTMobileSDK/FTSDKCore/Protocol'
		end

		c.subspec 'URLSessionAutoInstrumentation' do |a|
			a.source_files = 'FTMobileSDK/FTSDKCore/URLSessionAutoInstrumentation/**/*{.h,.m}'
			a.dependency 'FTMobileSDK/FTSDKCore/Protocol'
			a.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Swizzle'
		end

		c.subspec 'Exception' do |e|
			e.source_files = 'FTMobileSDK/FTSDKCore/Exception/*{.h,.m}'
			e.dependency 'FTMobileSDK/FTSDKCore/Protocol'
			e.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Base'
		end

		c.subspec 'LongTask' do |a|
			a.source_files = 'FTMobileSDK/FTSDKCore/LongTask/**/*{.h,.m}'
			a.dependency 'FTMobileSDK/FTSDKCore/BaseUtils'
		end

		c.subspec 'Protocol' do |r|
			r.source_files = 'FTMobileSDK/FTSDKCore/Protocol/**/*{.h,.m}'
		end

		c.subspec 'BaseUtils' do |b|

			b.subspec 'Base' do |bb|
				bb.source_files = 'FTMobileSDK/FTSDKCore/BaseUtils/Base/*{.h,.m}'
			end

			b.subspec 'Thread' do |bb|
				bb.source_files = 'FTMobileSDK/FTSDKCore/BaseUtils/Thread/*{.h,.m}'
			end

			b.subspec 'Swizzle' do |bb|
				bb.source_files = 'FTMobileSDK/FTSDKCore/BaseUtils/Swizzle/*{.h,.m,.c}'
				bb.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Base'
			end
		end

		c.subspec 'Logger' do |l|
			l.source_files = 'FTMobileSDK/FTSDKCore/Logger/*{.h,.m,.c}'
			l.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Base'
		end

		c.subspec 'FTWKWebView' do |j|
			j.source_files = 'FTMobileSDK/FTSDKCore/FTWKWebView/**/*{.h,.m}'
			j.dependency 'FTMobileSDK/FTSDKCore/Protocol'
			j.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Swizzle'
		end

		c.subspec 'DataManager' do |bb|
			bb.source_files =  'FTMobileSDK/FTSDKCore/DataManager/**/*{.h,.m}'
			bb.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Thread'
			bb.dependency 'FTMobileSDK/FTSDKCore/BaseUtils/Base'
		end
	end
end


