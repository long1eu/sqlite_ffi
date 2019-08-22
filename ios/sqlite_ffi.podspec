#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'sqlite_ffi'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter project.'
  s.description      = <<-DESC
A new Flutter project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }

  s.platform = :ios
  s.library = 'sqlite3'
  s.source_files = '../cpp/**/*'
  s.public_header_files = '../cpp/**/*.h'

  s.dependency 'Flutter'
  s.ios.deployment_target = '8.0'
end

