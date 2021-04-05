# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name    = "arcana"
  s.summary = "file/libmagic based mime sniffing in pure Ruby"

  s.platform = Gem::Platform::RUBY
  s.version = "0.1.0"
  s.license = "BSD-2-Clause"
  s.author = "John Hawthorn"
  s.email = 'john@hawthorn.email'
  s.homepage = 'https://github.com/jhawthorn/arcana'

  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/jhawthorn/arcana/issues',
    'source_code_uri'   => 'https://github.com/jhawthorn/arcana',
    'documentation_uri' => 'https://www.rubydoc.info/gems/arcana',
  }

  s.files = Dir['lib/**/*.rb']

  s.require_paths << 'lib'
end
