# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'EmoBot' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for EmoBot
  pod 'AffdexSDK-iOS'

  target 'EmoBotTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'EmoBotUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        if (target.name == "AWSCore") || (target.name == 'AWSKinesis')
            target.build_configurations.each do |config|
                config.build_settings['BITCODE_GENERATION_MODE'] = 'bitcode'
            end
        end
    end
end
