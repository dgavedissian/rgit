require "iniparse"

module Rgit
  class Repository
    attr_accessor :config
    private :config=

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

    def path(*path, mkdir=false)
      File.join(@gitdir, *path)
    end

    def file(*path, mode, mkdir=false, &block)
      path_in_repo = self.path(*path, mkdir)
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

        repo.path("branches", true)
        repo.path("objects", true)
        repo.path("refs", "tags", true)
        repo.path("refs", "heads", true)
        
        # .git/description
        repo.file("description", "w") do |f|
          f.write("Unnamed repository.")
        end

        # .git/HEAD
        repo.file("HEAD", "w") do |f|
          f.write("ref: refs/head/master\n")
        end

        # Default config.
        repo.file("config", "w") do |f|
          repo.config = IniParse.gen do |doc|
            doc.section("core") do |core|
              vehicle.option("repositoryformatversion", 0)
              vehicle.option("filemode", false)
              vehicle.option("bare", false)
            end
          end
          f.write(repo.config.to_ini)
        end
        
        repo
      end
    end
  end
end