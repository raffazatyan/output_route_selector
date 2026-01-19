#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint output_route_selector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'output_route_selector'
  s.version          = '1.1.0'
  s.summary          = 'A Flutter plugin to select audio output routes on iOS devices.'
  s.description      = <<-DESC
A Flutter plugin that allows you to select and manage audio output routes (speaker, receiver, bluetooth, wired headset) on iOS devices.
                       DESC
  s.homepage         = 'https://github.com/raffazatyan/output_route_selector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'raffazatyan' => 'raffazatyan@gamil.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.resources        = 'Classes/**/*.xcassets'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
