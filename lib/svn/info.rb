module Svn
  class Info
    def initialize(repo_path, rev)
      @repo_path = repo_path
      @revision = Integer(rev)
      get_changed
    end

    # Used by: update-version.h.rb
    def branches
      [*@added_files, *@updated_files].map { |x| x[/((?:branches\/)?.+?)\//, 1] }.uniq
    end

    private

    def get_changed
      @added_files = []
      @updated_files = []
      svnlook("changed").each_line do |line|
        if /^(.).  (.*)$/ =~ line
          modified_type = $1
          path = $2
          case modified_type
          when "A"
            add_path(path, @added_files)
          when "D"
            # noop
          else
            add_path(path, @updated_files)
          end
        else
          raise "unknown format: #{line}"
        end
      end
    end

    def add_path(path, files)
      unless directory_path?(path)
        files << path
      end
    end

    def svnlook(command, *others)
      `svnlook #{command} #{@repo_path} -r #{@revision} #{others.join(' ')}`.force_encoding("ASCII-8BIT")
    end

    def directory_path?(path)
      path[-1] == ?/
    end
  end
end
