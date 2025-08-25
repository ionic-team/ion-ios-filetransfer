Pod::Spec.new do |spec|
  spec.name                   = 'IONFileTransferLib'
  spec.version                = '1.0.1'

  spec.summary                = 'A native iOS library for download and upload files.'
  spec.description            = 'A Swift library for iOS that provides simple way to download and upload files. Download and upload files with a secure, clean and modern API.'

  spec.homepage               = 'https://github.com/ionic-team/ion-ios-filetransfer'
  spec.license                = { :type => 'MIT', :file => 'LICENSE' }
  spec.author                 = { 'OutSystems Mobile Ecosystem' => 'rd.mobileecosystem.team@outsystems.com' }
  
  spec.source                 = { :http => "https://github.com/ionic-team/ion-ios-filetransfer/releases/download/#{spec.version}/IONFileTransferLib.zip", :type => "zip" }
  spec.vendored_frameworks    = "IONFileTransferLib.xcframework"

  spec.ios.deployment_target  = '14.0'
  spec.swift_versions         = ['5.0', '5.1', '5.2', '5.3', '5.4', '5.5', '5.6', '5.7', '5.8', '5.9']
end
