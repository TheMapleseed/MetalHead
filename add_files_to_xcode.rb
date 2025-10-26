#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MetalHead.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'MetalHead' }

# Get the main group (MetalHead folder)
main_group = project.main_group.groups.find { |g| g.name == 'MetalHead' }

# All Swift and Metal files to add
files_to_add = [
  'MetalHead/MetalHeadApp.swift',
  'MetalHead/ContentView.swift',
  'MetalHead/Core/Rendering/MetalRenderingEngine.swift',
  'MetalHead/Core/Rendering/Graphics2D.swift',
  'MetalHead/Core/Rendering/Shaders.metal',
  'MetalHead/Core/Rendering/MetalRayTracing.swift',
  'MetalHead/Core/Rendering/GeometryShaders.swift',
  'MetalHead/Core/Audio/AudioEngine.swift',
  'MetalHead/Core/Input/InputManager.swift',
  'MetalHead/Core/Memory/MemoryManager.swift',
  'MetalHead/Core/Synchronization/UnifiedClockSystem.swift',
  'MetalHead/Core/UnifiedMultimediaEngine.swift',
  'MetalHead/Utilities/Extensions/SIMDExtensions.swift',
  'MetalHead/Utilities/Performance/PerformanceMonitor.swift',
  'MetalHead/Utilities/ErrorHandling/ErrorHandler.swift',
  'MetalHead/Utilities/Logging/Logger.swift'
]

files_to_add.each do |file_path|
  if File.exist?(file_path)
    # Navigate to the correct group based on path
    path_parts = file_path.split('/')
    path_parts = path_parts[1..-1] # Remove 'MetalHead' prefix
    
    current_group = main_group
    
    # Navigate/create groups for nested paths
    (path_parts[0..-2]).each do |part|
      if part == 'MetalHead'
        next
      end
      group = current_group.groups.find { |g| g.name == part }
      unless group
        group = current_group.new_group(part)
      end
      current_group = group
    end
    
    # Add the file to the current group
    file_ref = current_group.new_reference(file_path)
    target.add_file_references([file_ref]) unless target.source_build_phase.files_references.include?(file_ref)
    
    puts "Added: #{file_path}"
  else
    puts "Not found: #{file_path}"
  end
end

project.save
puts "\nProject saved successfully!"

