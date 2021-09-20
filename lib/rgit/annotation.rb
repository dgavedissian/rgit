
module Rgit
  # A commit author and message.
  class Annotation
    def initialize(author: "Unknown Author <unknown@author.com>", message: "")
      @author = author
      @message = message
    end
    
    attr_reader :author, :message
  end
end