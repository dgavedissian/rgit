# $:.unshift File.expand_path("lib/rgit")

require './lib/rgit.rb'
require 'main'

Main {
  mode 'init' do
    puts self.class
    def run()
      puts 'installing...'
    end
  end
}