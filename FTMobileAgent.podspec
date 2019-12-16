Pod::Spec.new do |s|

  s.name         = "FTMobileAgent"
  #s.version      = "1.0.0-alpha.9"
  s.version      = "$JENKINS_DYNAMIC_VERSION"
  s.summary      = "驻云 DataFlux FT Mobile SDK，FT GateWay 数据传输"
  s.description  = "驻云 DataFlux FT Mobile SDK，将通过 SDK 将写入数据 传输至 FT GateWay。"
  s.homepage     = "https://www.dataflux.cn/"

  s.license      = { type: 'MIT', text: <<-LICENSE
Copyright (c) 2018-2019 OnCloud <support@jiagouyun.com>
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
                       LICENSE
                   }

  s.authors             = { "hulilei" => "hulilei@jiagouyun.com","Brandon Zhang" => "zhangbo@jiagouyun.com" }
  s.platform     = :ios, "8.0"
  # s.ios.deployment_target = "8.0"
  # s.osx.deployment_target = "10.7"
  # s.watchos.deployment_target = "2.0"
  # s.tvos.deployment_target = "9.0"

  # s.source       = { :http => "https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTMobileAgent_1.0.0-alpha.9.zip" }
  s.source       = { :http => "https://zhuyun-static-files-production.oss-cn-hangzhou.aliyuncs.com/ft-sdk-package/ios/FTMobileAgent_$JENKINS_DYNAMIC_VERSION.zip" }
  s.vendored_frameworks = 'FTMobileAgent.framework'
  # s.dependency "JSONKit", "~> 1.4"

end
