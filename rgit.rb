# $:.unshift File.expand_path("lib/rgit")

require './lib/rgit.rb'
require 'main'

Main {
  mode 'init' do
    argument 'path'
    def run()
      if params["path"].given?
        path = params['path'].value
        Rgit::Repository.create(path)
        puts "Created repository at #{path}"
      end
    end
  end
}