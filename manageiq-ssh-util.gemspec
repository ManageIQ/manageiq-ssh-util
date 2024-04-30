$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "manageiq/ssh/util/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "manageiq-ssh-util"
  s.version     = ManageIQ::SSH::Util::VERSION
  s.authors     = ["ManageIQ Developers"]
  s.homepage    = "https://github.com/ManageIQ/manageiq-ssh-util"
  s.summary     = "ManageIQ wrapper library for net-ssh"
  s.description = "ManageIQ wrapper library for net-ssh"
  s.licenses    = ["Apache-2.0"]

  s.files = Dir["{app,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md", "CHANGELOG.md"]

  s.required_ruby_version = Gem::Requirement.new(">= 2.6")

  s.add_dependency "activesupport"
  s.add_dependency "bcrypt_pbkdf", ">= 1.0", "< 2.0"
  s.add_dependency "ed25519",      ">= 1.2", "< 1.3"
  s.add_dependency "net-ssh",      "~> 7.2"
  s.add_dependency "net-sftp",     "~> 4.0"

  s.add_development_dependency "manageiq-style"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "simplecov", ">= 0.21.2"
end
