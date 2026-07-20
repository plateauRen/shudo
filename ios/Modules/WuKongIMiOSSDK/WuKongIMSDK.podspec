#
# Be sure to run `pod lib lint WuKongIMSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WuKongIMSDK'
  s.version          = '1.1.0'
  s.summary          = '悟空IM是一款简单，高效，支持完全私有化的即时通讯.'

  s.description      = <<-DESC
悟空IM是一款简单，高效，支持完全私有化的即时通讯，提供群聊，点对点通讯解决方案.
                       DESC

  s.homepage         = 'https://github.com/WuKongIM/WuKongIMiOSSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tangtaoit' => 'tt@tgo.ai' }
  s.source           = { :git => "https://github.com/WuKongIM/WuKongIMiOSSDK.git" }
  s.platform     = :ios, '11.0'
  s.requires_arc = true

  s.ios.deployment_target = '11.0'

  # AMR 静态库仅含真机 arm64（及 Intel 模拟器）。不用 vendored_libraries，避免 Apple Silicon 模拟器误链。
  # 模拟器用 amr_simulator_stubs.c；真机通过 OTHER_LDFLAGS[sdk=iphoneos*] 链接。
  s.preserve_paths = 'WuKongIMSDK/Classes/private/arm/lib/*.a'

  s.source_files = 'WuKongIMSDK/Classes/**/*'
  s.exclude_files = 'WuKongIMSDK/Classes/private/arm/lib/**/*'
  s.public_header_files =  'WuKongIMSDK/Classes/**/*.h'
  s.private_header_files = 'WuKongIMSDK/Classes/private/**/*.h'
  s.frameworks = 'UIKit', 'MapKit', 'Security'

  s.resource_bundles = {
    'WuKongIMSDK' => ['WuKongIMSDK/Assets/*.png','WuKongIMSDK/Assets/Migrations/*']
  }

  s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -lopencore-amrnb -lopencore-amrwb -lvo-amrwbenc',
      'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]' => '$(inherited) "$(PODS_TARGET_SRCROOT)/WuKongIMSDK/Classes/private/arm/lib"'
  }

  s.dependency 'CocoaAsyncSocket', '~> 7.6.5'
  s.dependency 'FMDB/SQLCipher', '~>2.7.5'
  s.dependency '25519', '~>2.0.2'
end
