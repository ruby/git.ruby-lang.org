require "English"
require "time"
require "digest/sha2"

require "nkf"
begin
  require "uconv"
rescue LoadError
  module Uconv
    class Error < StandardError
    end
    def self.u8toeuc(str)
      raise Error
    end
  end
end

module Svn
  class Info
    # Used by: commit-email.rb
    attr_reader :author, :log, :date
    attr_reader :added_files, :deleted_files, :updated_files
    attr_reader :added_dirs, :deleted_dirs, :updated_dirs
    attr_reader :diffs
    attr_reader :revision
    attr_reader :entire_sha256

    def initialize(repo_path, rev)
      @repo_path = repo_path
      @revision = Integer(rev)
      get_info
      get_dirs_changed
      get_changed
      get_diff
      get_sha256
    end

    # Used by: commit-email.rb
    def author_email
      "#{@author}@ruby-lang.org"
    end

    # Used by: commit-email.rb, update-version.h.rb
    def branches
      sha256.map{|x,| x[/((?:branches\/)?.+?)\//, 1]}.uniq
    end

    private

    def get_info
      @log = force_to_utf8(svnlook("log").chomp)
      change_lang("C") do
        infos = svnlook("info").split(/^/, 4)
        @author, @date, @log_size, _ = infos.collect{|x| x.chomp}
        @date = Time.parse(@date)
      end
    end

    def get_dirs_changed
      @changed_dirs = svnlook("dirs-changed").split(/^/)
      @changed_dirs.collect!{|dir| dir.chomp}
    end

    def get_changed
      @added_files = []
      @added_dirs = []
      @deleted_files = []
      @deleted_dirs = []
      @updated_files = []
      @updated_dirs = []
      svnlook("changed").each_line do |line|
        if /^(.).  (.*)$/ =~ line
          modified_type = $1
          path = $2
          case modified_type
          when "A"
            add_path(path, @added_files, @added_dirs)
          when "D"
            add_path(path, @deleted_files, @deleted_dirs)
          else
            add_path(path, @updated_files, @updated_dirs)
          end
        else
          raise "unknown format: #{line}"
        end
      end
    end

    def add_path(path, files, dirs)
      if directory_path?(path)
        dirs << path
      else
        files << path
      end
    end

    def get_diff
      change_lang("C") do
        @diff = svnlook("diff")
      end
      @diffs = {}
      last_target = nil
      in_content = in_header = false
      @diff.each_line do |line|
        case line
        when /^(Modified|Added|Deleted|Copied|Property changes on):\s+(.+)/
          in_content = false
          in_header = nil
          last_target = get_diff_handle_start($2.chomp, normalize_type($1))
        when /^@@/
          in_content = true
          in_header = false
        else
          if in_content
            case line
            when /^-/
              last_target[:deleted] += 1
            when /^\+/
              last_target[:added] += 1
            end
          end
        end

        if in_content or in_header
          last_target[:body] << line
        end

        in_header = true if in_header.nil?

      end

      @diffs.each do |key, values|
        values.each do |type, value|
          value[:body] = force_to_utf8(value[:body])
        end
      end
    end

    NORMALIZE_TYPE_TABLE = {
      "property_changes_on" => :property_changed
    }

    def normalize_type(type_info_str)
      normalized = type_info_str.gsub(/ /, '_').downcase
      if NORMALIZE_TYPE_TABLE.has_key?(normalized)
        NORMALIZE_TYPE_TABLE[normalized]
      else
        normalized.intern
      end
    end

    def get_diff_handle_start(target, type)
      @diffs[target] ||= {}
      @diffs[target][type] = {
        :type => type,
        :body => "",
        :added => 0,
        :deleted => 0,
      }
      @diffs[target][type]
    end

    def get_sha256
      sha = Digest::SHA256.new
      @sha256 = {}
      [
        @added_files,
#        @deleted_files,
        @updated_files,
      ].each do |files|
        files.each do |file|
          content = svnlook("cat", file)
          sha << content
          @sha256[file] = {
            :file => file,
            :revision => @revision,
            :sha256 => Digest::SHA256.hexdigest(content),
          }
        end
      end
      @entire_sha256 = sha.hexdigest
    end

    def svnlook(command, *others)
      `svnlook #{command} #{@repo_path} -r #{@revision} #{others.join(' ')}`.force_encoding("ASCII-8BIT")
    end

    def directory_path?(path)
      path[-1] == ?/
    end

    def force_to_utf8(str)
      begin
        # check UTF-8 or not
        Uconv.u8toeuc(str)
        str
      rescue Uconv::Error
        NKF.nkf("-w", str)
      end
    end

    def change_lang(lang)
      orig = ENV["LANG"]
      begin
        ENV["LANG"] = lang
        yield
      ensure
        ENV["LANG"] = orig
      end
    end
  end
end
