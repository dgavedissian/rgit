require "iniparse"

module Rgit
  class Repository
    attr_accessor :config

    def initialize(worktree, new_repository=false)
      @worktree = worktree
      @gitdir = File.join(worktree, ".git")

      return if new_repository

      if !force && !File.directory?(@gitdir)
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

        repo = Repository.new(worktree, true)

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
          return Repository.new(path)
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