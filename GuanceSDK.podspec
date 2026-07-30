Pod::Spec.new do |s|

	s.name         = "GuanceSDK"
	s.version      = "1.6.6"
	s.summary      = "Guance Cloud iOS Data Collection SDK"
	#s.description  = ""
	s.homepage     = "https://github.com/GuanceCloud/datakit-ios.git"

	s.license      = { type: 'Apache', :file => 'LICENSE'}
	s.authors             = { "hulilei" => "hulilei@guance.com","Brandon Zhang" => "zhangbo@guance.com" }
	s.default_subspec = 'Agent'
	s.swift_versions = ['5.0']

	s.ios.deployment_target = '12.0'
	s.osx.deployment_target = '10.14'
	s.tvos.deployment_target = '12.0'
	s.libraries    = 'z'
	header_search_paths = '$(inherited) $(PODS_TARGET_SRCROOT) $(PODS_TARGET_SRCROOT)/Sources $(PODS_TARGET_SRCROOT)/Sources/Core/** $(PODS_TARGET_SRCROOT)/Sources/Agent/** $(PODS_TARGET_SRCROOT)/Sources/WidgetExtension $(PODS_TARGET_SRCROOT)/Sources/SessionReplay/**'
	s.pod_target_xcconfig = {
		'DEFINES_MODULE' => 'YES',
		'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES',
		'HEADER_SEARCH_PATHS' => header_search_paths,
		'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GUANCE_COCOAPODS=1'
	}

	#$JENKINS_DYNAMIC_VERSION replacing "#{s.version}" will cause an error during pod valid phase
	s.source       = { :git => "https://github.com/GuanceCloud/datakit-ios.git", :tag => s.version.to_s }

    s.resource_bundle = {
      "FTSDKPrivacyInfo" => "Sources/Resources/PrivacyInfo.xcprivacy"
    }

	s.subspec  'Agent' do | agent |
		core_path='Sources/Agent/'
		agent.ios.deployment_target = '12.0'
		agent.osx.deployment_target = '10.14'
		agent.tvos.deployment_target = '12.0'
		agent.source_files = 'Sources/*.{h}',
			'Sources/Agent/**/*{.h,.m}'
		agent.ios.exclude_files = 'Sources/Agent/AutoTrack/Mac/**/*'
		agent.tvos.exclude_files = 'Sources/Agent/AutoTrack/Mac/**/*'
		agent.dependency 'GuanceSDK/Core'
	end

	s.subspec 'WidgetExtension' do |e|
		e.platform = :ios, '12.0'
		e.source_files = 'Sources/WidgetExtension/*{.h,.m}','Sources/Agent/Config/*.{h,m}','Sources/Agent/ExternalData/*{.h,.m}','Sources/Agent/Extension/*{.h,.m}'
		e.dependency 'GuanceSDK/Core/FTRUM'
		e.dependency 'GuanceSDK/Core/URLSessionAutoInstrumentation'
		e.dependency 'GuanceSDK/Core/Logger'
	end

	s.subspec 'Extension' do |e|
		e.platform = :ios, '12.0'
		e.dependency "#{s.name}/WidgetExtension"
	end

	s.subspec 'Core' do |c|
		c.ios.deployment_target = '12.0'
		c.osx.deployment_target = '10.14'
		c.tvos.deployment_target = '12.0'

		c.subspec 'FTRUM' do |r|
			r.source_files = 'Sources/Core/FTRUM/**/*.{h,m,c,cpp}'
			r.dependency 'GuanceSDK/Core/BaseUtils/Base'
			r.dependency 'GuanceSDK/Core/Protocol'
		end

		c.subspec 'URLSessionAutoInstrumentation' do |a|
			a.source_files = 'Sources/Core/URLSessionAutoInstrumentation/**/*{.h,.m}'
			a.dependency 'GuanceSDK/Core/Protocol'
			a.dependency 'GuanceSDK/Core/BaseUtils/Swizzle'
		end

		c.subspec 'Protocol' do |r|
			r.source_files = 'Sources/Core/Protocol/**/*{.h,.m}'
		end

		c.subspec 'RemoteConfig' do |r|
			r.source_files = 'Sources/Core/RemoteConfig/*{.h,.m}'
			r.dependency 'GuanceSDK/Core/DataManager'
		end

		c.subspec 'BaseUtils' do |b|
			b.subspec 'Base' do |bb|
				bb.source_files = 'Sources/Core/BaseUtils/Base/**/*{.h,.m,.c}'
				bb.dependency 'GuanceSDK/Core/BaseUtils/Thread'
			end

			b.subspec 'Thread' do |bb|
				bb.source_files = 'Sources/Core/BaseUtils/Thread/**/*{.h,.m}'
			end

			b.subspec 'Swizzle' do |bb|
				bb.source_files = 'Sources/Core/BaseUtils/Swizzle/*{.h,.m,.c}'
				bb.dependency 'GuanceSDK/Core/BaseUtils/Base'
			end
		end

		c.subspec 'Logger' do |l|
			l.source_files = 'Sources/Core/Logger/*{.h,.m}'
			l.dependency 'GuanceSDK/Core/BaseUtils/Base'
			l.dependency 'GuanceSDK/Core/Protocol'
		end

		c.subspec 'FTWKWebView' do |j|
			j.ios.deployment_target = '12.0'
			j.osx.deployment_target = '10.14'
			j.source_files = 'Sources/Core/FTWKWebView/**/*{.h,.m}'
			j.dependency 'GuanceSDK/Core/Protocol'
			j.dependency 'GuanceSDK/Core/BaseUtils/Swizzle'
		end

		c.subspec 'DataManager' do |bb|
			bb.source_files = [
				'Sources/Core/DataManager/*{.h,.m}',
				'Sources/Core/DataManager/Upload/*{.h,.m}',
				'Sources/Core/DataManager/Storage/**/*{.h,.m}',
				'Sources/Core/DataFilter/*{.h,.m}'
			]
			bb.dependency 'GuanceSDK/Core/BaseUtils/Thread'
			bb.dependency 'GuanceSDK/Core/BaseUtils/Base'
			bb.dependency 'GuanceSDK/Core/Protocol'
		end
	end

	s.subspec 'SessionReplay' do |sr|
		 sr.ios.deployment_target = '12.0'
		 sr.osx.deployment_target = '10.14'
		 sr.public_header_files = 'Sources/SessionReplay/Public/*.h'
		 sr.source_files = 'Sources/SessionReplay/**/*{.h,.m}'
		 sr.dependency 'GuanceSDK/Core'
		 sr.pod_target_xcconfig = {
			 'HEADER_SEARCH_PATHS' => header_search_paths,
			 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GUANCE_COCOAPODS=1'
		 }
	end

	s.subspec 'FTSessionReplay' do |sr|
		sr.ios.deployment_target = '12.0'
		sr.osx.deployment_target = '10.14'
		sr.dependency "#{s.name}/SessionReplay"
	end
end
