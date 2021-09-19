require "zlib"
require "digest"

module Rgit
  # A generic Git object.
  # 'serialize()' and 'deserialize(data)' is expected to be implemented by child classes.
  class Object
    def initialize(repo, data = nil)
      @repo = repo
      self.deserialize(data) if data != nil
    end

    def repo
      @repo
    end
    
    def serialize
      raise "serialize unimplemented"
    end

    def deserialize(data)
      raise "deserialize unimplemented"
    end
  end

  class Blob < Object
    def type
      "blob"
    end

    def serialize
      @data
    end

    def deserialize(data)
      @data = data
    end
  end

  class << self
    def object_create(type, data, repo)
      object_class = case type
      when "commit"
        Commit
      when "tree"
        Tree
      when "tag"
        Tag
      when "blob"
        Blob
      else
        return nil
      end
      object_class.new(repo, data)
    end

    def object_find(repo, name, type=nil, follow=true)
      name
    end

    def object_read(repo, sha)
      repo.file("objects", sha[0...2], sha[2...], mode: "rb") do |f|
        data = Zlib::Inflate.inflate(f.read)

        # Get object type.
        type_delim = data.index(' ')
        type = data[0...type_delim]
      
        # Read and validate object size.
        size_delim = data.index('\0', type_delim)

        # puts data[type_delim + 1...]
        # puts "#{size_delim}"
        # puts size_delim.type

        size = data[type_delim + 1...size_delim].to_i
        raise "Malformed object #{sha}: bad length" if size != data.length - size_delim - 1

        object = create_object(type, data[size_delim + 1...])
        raise "Unknown type #{type} for object #{sha}" if object == nil
      end

      nil
    end

    def object_write(object, update_repo=true)
      data = object.serialize
      data = "#{object.type} #{data.length}\0" + data 
      sha = Digest::SHA1.hexdigest data

      # print data

      if update_repo
        object.repo.file("objects", sha[0...2], sha[2...], mode: "wb", mkdir: true) do |f|
          f.write(Zlib::Deflate.deflate(data))
        end
      end

      sha
    end
  end
end