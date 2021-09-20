require "iniparse"
require "pathname"

module Rgit
  class Repo
    attr_accessor :config

    def initialize(worktree, new_repository=false)
      @worktree = worktree
      @gitdir = File.join(worktree, ".git")

      return if new_repository

      if !File.directory?(@gitdir)
        raise "#{@gitdir} is not a git repository"
      end

      config_path = self.path("config")
      if !File.exists?(config_path)
        raise "#{@gitdir} does not contain a configuration"
      end
      @conf = IniParse.parse(File.read(config_path))

      version = @conf["core"]["repositoryformatversion"].to_i
      if version != 0
        raise "Unsupported repositoryformatversion #{version}"
      end
    end

    def path(*path)
      File.join(@gitdir, *path)
    end

    def create_dir(*path)
      FileUtils.mkdir_p(self.path(*path))
    end

    def file(*path, mode: "r", mkdir: false, &block)
      if mkdir
        self.create_dir(*path[0...-1])
      end
      path_in_repo = self.path(*path)
      File.open(path_in_repo, mode, &block)
    end

    def ref_create(ref, sha)
      file("refs", ref, mode: "w") do |f|
        f.write(sha + "\n")
      end
    end

    def ref_resolve(ref)
      data = file(ref) { |f| f.read[...-1] }
      if data.start_with?("ref:")
        ref_resolve(data[5...])
      else
        data
      end
    end

    def ref_list(path=nil)
      path = self.path("refs") if path.nil?
      result = {}
      Dir.children(path).sort.each do |f|
        full_path = File.join(path, f)
        if File.directory?(full_path)
          result[f] = ref_list(full_path)
        else
          result[f] = ref_resolve(Pathname(full_path).relative_path_from(@gitdir))
        end
      end

      result
    end

    def create_tag(name, ref, annotation=nil)
      sha = Rgit::Object.find(self, ref)

      if !annotation.nil?
        tag = Rgit::Tag.new(self)
        tag.data["object"] = sha
        tag.data["type"] = "commit"
        tag.data["tag"] = name
        tag.data["tagger"] = annotation.author
        tag.data[""] = annotation.message
        ref_create("tags/#{name}", Rgit::Object.write(tag, update_repo: true))
      else
        ref_create("tags/#{name}", sha)
      end
    end

    class << self
      def create(worktree)
        if File.exists?(worktree)
          if !File.directory?(worktree)
            raise "#{worktree} is not a directory"
          end
          if !Dir.empty?(worktree)
            raise "#{worktree} is not empty"
          end
        else
          Dir.mkdir(worktree)
        end

        repo = Repo.new(worktree, true)

        repo.create_dir("branches")
        repo.create_dir("objects")
        repo.create_dir("refs", "tags")
        repo.create_dir("refs", "heads")
        
        # .git/description
        repo.file("description", mode: "w") do |f|
          f.write("Unnamed repository.")
        end

        # .git/HEAD
        repo.file("HEAD", mode: "w") do |f|
          f.write("ref: refs/head/master\n")
        end

        # Default config.
        repo.file("config", mode: "w") do |f|
          repo.config = IniParse.gen do |doc|
            doc.section("core") do |core|
              core.option("repositoryformatversion", 0)
              core.option("filemode", false)
              core.option("bare", false)
            end
          end
          f.write(repo.config.to_ini)
        end
        
        repo
      end
      
      def find(path = ".")
        path = File.expand_path(path)
        if File.directory?(File.join(path, ".git"))
          return Repo.new(path)
        else
          parent = File.expand_path(File.join(path, ".."))
          if path == parent
            # Base case: we've hit the root path.
            return nil
          else
            return find(parent)
          end
        end
      end
    end
  end
end