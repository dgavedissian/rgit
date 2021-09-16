module Rgit
  class Object
    def initialize(repo, data = nil)
      @repo = repo
      self.deserialize(data) if data != nil
    end
    
    def serialize
      raise "Unimplemented"
    end

    def deserialize
      raise "Unimplemented"
    end
  end
end