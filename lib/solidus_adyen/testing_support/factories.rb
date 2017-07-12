GEM_ROOT = File.expand_path("../../../..", __FILE__)

Dir[File.join(GEM_ROOT, 'spec', 'factories', '**', '*.rb')].each do |file|
  require(file)
end
