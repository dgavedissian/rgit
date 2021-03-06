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
      raise NotImplementedError, "#{self.class} has not implemented serialize"
    end

    def deserialize(data)
      raise NotImplementedError, "#{self.class} has not implemented deserialize"
    end

    class << self
      # Will return nil if object_types does not contain type.
      def create(type, repo, data)
        object_types = {
          "commit" => Rgit::Commit,
          "tree" => Rgit::Tree,
           "tag" => Rgit::Tag,
          "blob" => Rgit::Blob
        }
        object_types[type].new(repo, data) if object_types.key?(type)
      end

      # Resolve 'name' to an object hash in 'repo'
      # It is aware of:
      # - HEAD
      # - short and long hashes
      # - tags
      # - branches
      # - remote branches
      def resolve(repo, name)
        name = name.strip

        # Empty name.
        return [] if name.empty?

        # HEAD
        return [repo.ref_resolve("HEAD")] if name == "HEAD"

        # short or long hashes.
        name.downcase!
        if /^[0-9A-Fa-f]{4,40}$/ =~ name
          # A complete hash.
          return [name] if name.length == 40

          # An incomplete short hash.
          prefix = name[0...2]
          path = repo.path("objects", prefix)
          if File.exist?(path)
            remainder = name[2...]
            return Dir.children(path)
              .select { |incomplete_hash| incomplete_hash.start_with?(remainder) }
              .map { |incomplete_hash| prefix + incomplete_hash }
          end
        end

        # tags and branches
        # TODO
        
        return []
      end

      def find(repo, name, type=nil, follow=true)
        candidates = resolve(repo, name)
        raise "No such reference #{name}" if candidates.empty?
        raise "Ambiguous reference #{name}: Candidates are:\n#{candidates}" if candidates.length > 1
        sha = candidates[0]
        return sha if type.nil?

        # Follow the object refs.
        while true
          object = read(repo, sha)
          return sha if object.type == type
          return nil if !follow

          # Follow tags.
          if object.is_a? Rgit::Tag
            sha = object.data["object"]
          elsif object.is_a? Rgit::Commit && type == "tree"
            sha = object.data["tree"]
          else
            return nil
          end
        end
      end

      def read(repo, sha)
        repo.file("objects", sha[0...2], sha[2...], mode: "rb") do |f|
          data = Zlib::Inflate.inflate(f.read)

          # Get object type.
          type_delim = data.index(' ')
          type = data[0...type_delim]
        
          # Read and validate object size.
          size_delim = data.index("\0", type_delim)
          size = data[type_delim + 1...size_delim].to_i
          raise "Malformed object #{sha}: bad length" if size != data.length - size_delim - 1

          object = create(type, repo, data[size_delim + 1...])
          raise "Unknown type #{type} for object #{sha}" if object.nil?
          return object
        end

        nil
      end

      def write(object, update_repo: true)
        data = object.serialize
        data = "#{object.type} #{data.length}\0" + data 
        sha = Digest::SHA1.hexdigest data

        if update_repo
          object.repo.file("objects", sha[0...2], sha[2...], mode: "wb", mkdir: true) do |f|
            f.write(Zlib::Deflate.deflate(data))
          end
        end

        sha
      end
    end
  end

  class Blob < Rgit::Object
    def type
      "blob"
    end

    attr_accessor :data

    def serialize
      @data
    end

    def deserialize(data)
      @data = data
    end
  end

  class Commit < Rgit::Object
    def type
      "commit"
    end

    attr_accessor :data

    def initialize(repo, data = nil)
      @data = {}
      super(repo, data)
    end

    def parents
      if @data.key?("parent")
        parents = @data["parent"]
        parents = [parents] unless parents.class == Array
      else
        nil
      end
    end

    def message
      @data.key?("") ? @data[""] : ""
    end

    def serialize
      out = ""

      # Serialize fields.
      @data.keys.each do |k|
        # Skip the message itself.
        next if k == ""

        value = @data[k]
        value = [value] unless value.class == Array

        value.each do |v|
          out << "#{k} #{v.gsub("\n", "\n ")}\n"
        end
      end

      # Serialize the message.
      message = @data[""]

      out << "\n#{message}"
    end

    def deserialize(data)
      def parse_commit(data, start=0, table=nil)
        table = {} if table.nil?
  
        space = data.index(" ", start)
        newline = data.index("\n", start)
  
        # If space appears before newline, we have a keyword.
  
        # Base Case: If newline appears first (or no space at all), we assume a blank line.
        # A blank line means the remainder of the data is the message.
        if space.nil? || newline < space
          raise "Expected the next character to be a newline" unless newline == start
          table[""] = data[start + 1...]
          return table
        end
  
        # Recursive case: Read a key-value pair and recurse for the next.
        key = data[start...space]
        data_end = start
        # Loop until we find a newline not followed by a space.
        loop do
          data_end = data.index("\n", data_end + 1)
          break if data[data_end + 1] != " "
        end
        # Grab the value, making sure to drop the leading space on continuation lines.
        value = data[space + 1...data_end].gsub("\n ", "\n")
        # Append to the Hash object. This works by adding the empty string to the table
        # if a given key doesnt exist, then appending 'value' to table[key] (which at this
        # point is guaranteed to exist)
        (table[key] ||= "") << value
        return parse_commit(data, start=data_end + 1, table=table)
      end

      @data = parse_commit(data)
    end
  end

  class Tree < Rgit::Object
    class Leaf
      attr_accessor :mode, :path, :sha

      def initialize(mode, path, sha)
        @mode = mode
        @path = path
        @sha = sha
      end
    end

    attr_accessor :items

    def type
      "tree"
    end

    def serialize
      result = ""
      @items.each do |i|
        # We need to decode the SHA string to binary.
        sha = [i.sha].pack("H*")
        result << "#{i.mode} #{i.path}\0#{sha}"
      end
      result
    end

    def deserialize(data)
      def tree_parse(data, start)
        # Mode.
        mode_end = data.index(" ", start)
        raise "Mode should be either 5 or 6 characters in size." unless mode_end - start == 5 || mode_end - start == 6
        mode = data[start...mode_end]

        # Path.
        path_end = data.index("\0", mode_end)
        path = data[mode_end + 1...path_end]

        # SHA. 20 bytes.
        # unpack("H*") encodes the binary SHA value as a string.
        # It always returns a singleton list, hence why we index 0.
        sha = data[path_end + 1...path_end + 21].unpack("H*")[0]

        return path_end + 21, Leaf.new(mode, path, sha)
      end

      pos = 0
      max = data.length
      @items = []
      while pos < max
        pos, tree_data = tree_parse(data, pos)
        @items << tree_data
      end
    end
  end

  class Tag < Rgit::Commit
    def type
      "tag"
    end
  end
end