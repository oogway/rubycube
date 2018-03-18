require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'rubycube'
  spec.version    = '0.4.0'
  spec.author     = 'Aditya Godbole'
  spec.license    = 'Artistic 2.0'
  spec.email      = 'code.aa@gdbl.me'
  spec.homepage   = 'http://github.com/adityagodbole/rubycube'
  spec.summary    = 'Interfaces for Ruby'
  spec.test_file  = 'test/test_interface.rb'
  spec.files      = Dir['**/*'].reject { |f| f.include?('git') }
  spec.cert_chain = Dir['certs/*']
  spec.required_ruby_version = ">= 2.0.0"

  spec.extra_rdoc_files = ['README.md', 'CHANGES', 'MANIFEST', 'examples/demo.rb']

  spec.add_dependency('dry-types')
  spec.add_development_dependency('dry-types')
  spec.add_development_dependency('test-unit')
  spec.add_development_dependency('rake')

  spec.description = <<-EOF
    CUBE (Composable Units of Behaviour) implements Interfaces, Traits and typechecks for Ruby.
  EOF
end
