Pod::Spec.new do |s|
  # Confirm the name is free before publishing: `pod trunk info Aksara`.
  s.name             = 'Aksara'
  s.version          = '0.1.0'
  s.summary          = 'Cross-platform live localization runtime with OTA updates.'
  s.description      = <<-DESC
    Aksara loads translations from a shared i18next-style JSON source of truth and
    renders them with over-the-air (OTA) updates, O(1) key lookup, and live UI
    reflection in SwiftUI. Mirrored 1:1 with the Kotlin runtime.
  DESC
  s.homepage         = 'https://github.com/iQbalADR/aksara'
  # A LICENSE file is required before `pod trunk push`. Pick a license first
  # (MIT / Apache-2.0) — see README.
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'iQbalADR' => 'iqbal.adr@gmail.com' }
  s.source           = { :git => 'https://github.com/iQbalADR/aksara.git', :tag => s.version.to_s }

  s.swift_versions = ['5.9']
  s.ios.deployment_target     = '15.0'
  s.osx.deployment_target     = '12.0'
  s.tvos.deployment_target    = '15.0'
  s.watchos.deployment_target = '8.0'

  # Core runtime only — no UI dependency.
  s.default_subspec = 'Core'

  s.subspec 'Core' do |core|
    core.source_files = 'ios/Sources/Aksara/**/*.swift'
    core.frameworks   = 'Foundation', 'Security', 'CryptoKit'
  end

  # SwiftUI live-binding layer (LocalizationManager + LocText).
  s.subspec 'SwiftUI' do |ui|
    ui.source_files = 'ios/Sources/AksaraSwiftUI/**/*.swift'
    ui.dependency 'Aksara/Core'
    ui.frameworks   = 'SwiftUI'
  end
end
