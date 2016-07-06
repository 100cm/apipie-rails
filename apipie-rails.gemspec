# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'apipie/version'

Gem::Specification.new do |s|
  s.name        = 'apipie-rails'
  s.version     = Apipie::VERSION
  s.authors     = ['Pavel Pokorny', 'Ivan Necas']
  s.email       = ['pajkycz@gmail.com', 'inecas@redhat.com']
  s.homepage    = 'http://github.com/Pajk/apipie-rails'
  s.summary     = 'Rails REST API documentation tool'
  s.description = 'Rails REST API documentation tool'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']

  s.add_development_dependency 'rails', '>= 3.0.10'
  s.add_dependency 'json'
  # s.add_dependency 'actionpack-page_caching'
  s.add_dependency 'meta-tags'
  s.add_development_dependency 'rspec-rails', '~> 2.14.2'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'maruku'
  s.add_development_dependency 'RedCloth'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
end
