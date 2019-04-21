#!/usr/bin/env ruby

require "optparse"
require "ostruct"

SENDMAIL = "/usr/sbin/sendmail"

CommitEmailInfo = Struct.new(
  :author,
  :author_email,
  :revision,
  :entire_sha256,
  :date,
  :log,
  :diffs,
  :branches,

  # TODO
  :added_files, :deleted_files, :updated_files,
  :added_dirs, :deleted_dirs, :updated_dirs,
)

class GitInfoBuilder
  def initialize(repo_path)
    @repo_path = repo_path
  end

  # TODO: should we generate info for each revision between oldrev and newrev?
  def build(_oldrev, newrev, refname)
    diffs = build_diffs(newrev)

    info = CommitEmailInfo.new
    info.author = git_show(newrev, format: '%an')
    info.author_email = git_show(newrev, format: '%aE')
    info.revision = newrev
    info.entire_sha256 = newrev
    info.date = Time.at(Integer(git_show(newrev, format: '%at')))
    info.log = git_show(newrev, format: '%B')
    info.diffs = diffs
    info.branches = [git('rev-parse', '--symbolic', '--abbrev-ref', refname).strip]
    info
  end

  private

  # SVN version:
  # {
  #   "filename" => {
  #     "[modified|added|deleted|copied|property_changed]" => {
  #       type: "[modified|added|deleted|copied|property_changed]",
  #       body: "diff body", # not implemented because not used
  #       added: Integer,
  #       deleted: Integer,
  #     }
  #   }
  # }
  def build_diffs(revision)
    diffs = {}

    # Using "#{revision}^" instead of oldrev to exclude diff from unrelated revision
    git('diff', '--name-status', "#{revision}^", revision).each_line do |line|
      status, path, newpath = line.strip.split("\t", 3)
      diff = build_diff(revision, newpath || path)

      case status
      when 'A'
        diffs[path] = { 'added' => { type: 'added', **diff } }
      when 'M'
        diffs[path] = { 'modified' => { type: 'modified', **diff } }
      when 'C'
        diffs[path] = { 'copied' => { type: 'copied', **diff } }
      when 'D'
        diffs[path] = { 'deleted' => { type: 'deleted', **diff } }
      when /\AR/ # R100
        # TODO: implement something
      else
        $stderr.puts "unexpected git diff status: #{status}"
      end
    end

    diffs
  end

  def build_diff(revision, path)
    diff = { added: 0, deleted: 0 } # :body not implemented because not used
    line = git('diff', '--numstat', "#{revision}^", revision, path).lines.first
    return diff if line.nil? || line.blank?

    added, deleted, _ = line.split("\t", 3)
    if added
      diff[:added] = Integer(added)
    end
    if deleted
      diff[:deleted] = Integer(deleted)
    end
  end

  def git_show(revision, format:)
    git('show', "--pretty=#{format}", revision).strip
  end

  def git(*args)
    command = ['git', *args]
    output = with_lang('C') { IO.popen(command, &:read) }
    unless $?.success?
      raise "failed to execute '#{command.join(' ')}':\n#{output}"
    end
    output
  end

  def with_lang(lang)
    orig = ENV['LANG']
    begin
      ENV['LANG'] = lang
      yield
    ensure
      ENV['LANG'] = orig
    end
  end
end

def parse(args)
  options = OpenStruct.new
  options.to = []
  options.error_to = []
  options.from = nil
  options.repository_uri = nil
  options.rss_path = nil
  options.rss_uri = nil
  options.name = nil
  options.viewvc_uri = nil
  options.vcs = "svn"

  opts = OptionParser.new do |opts|
    opts.separator ""

    opts.on("-I", "--include [PATH]",
            "Add [PATH] to load path") do |path|
      $LOAD_PATH.unshift(path)
    end

    opts.on("-t", "--to [TO]",
            "Add [TO] to to address") do |to|
      options.to << to unless to.nil?
    end

    opts.on("-e", "--error-to [TO]",
            "Add [TO] to to address when error is occurred") do |to|
      options.error_to << to unless to.nil?
    end

    opts.on("-f", "--from [FROM]",
            "Use [FROM] as from address") do |from|
      options.from = from
    end

    opts.on("--viewer-uri [URI]",
            "Use [URI] as URI of revision viewer") do |uri|
      options.viewer_uri = uri
    end

    opts.on("-r", "--repository-uri [URI]",
            "Use [URI] as URI of repository") do |uri|
      options.repository_uri = uri
    end

    opts.on("--rss-path [PATH]",
            "Use [PATH] as output RSS path") do |path|
      options.rss_path = path
    end

    opts.on("--rss-uri [URI]",
            "Use [URI] as output RSS URI") do |uri|
      options.rss_uri = uri
    end

    opts.on("--name [NAME]",
            "Use [NAME] as repository name") do |name|
      options.name = name
    end

    opts.on("--vcs [VCS]",
            "Use [VCS] as VCS (git, svn)") do |vcs|
      options.vcs = vcs
    end

    opts.on_tail("--help", "Show this message") do
      puts opts
      exit
    end
  end

  return opts.parse!(args), options
end

def make_body(info, params)
  body = ""
  body << "#{info.author}\t#{format_time(info.date)}\n"
  body << "\n"
  body << "  New Revision: #{info.revision}\n"
  body << "\n"
  body << "  #{params[:viewer_uri]}#{info.revision}\n"
  body << "\n"
  body << "  Log:\n"
  body << info.log.lstrip.gsub(/^\t*/, "    ").rstrip
  body << "\n\n"
  body << added_dirs(info)
  body << added_files(info)
  body << deleted_dirs(info)
  body << deleted_files(info)
  body << modified_dirs(info)
  body << modified_files(info)
  body.rstrip + "\n"
end

def format_time(time)
  time.strftime('%Y-%m-%d %X %z (%a, %d %b %Y)')
end

def changed_items(title, type, items)
  rv = ""
  unless items.empty?
    rv << "  #{title} #{type}:\n"
    rv << items.collect {|item| "    #{item}\n"}.join('')
  end
  rv
end

def changed_files(title, files)
  changed_items(title, "files", files)
end

def added_files(info)
  changed_files("Added", info.added_files)
end

def deleted_files(info)
  changed_files("Removed", info.deleted_files)
end

def modified_files(info)
  changed_files("Modified", info.updated_files)
end

def changed_dirs(title, files)
  changed_items(title, "directories", files)
end

def added_dirs(info)
  changed_dirs("Added", info.added_dirs)
end

def deleted_dirs(info)
  changed_dirs("Removed", info.deleted_dirs)
end

def modified_dirs(info)
  changed_dirs("Modified", info.updated_dirs)
end


CHANGED_TYPE = {
  :added => "Added",
  :modified => "Modified",
  :deleted => "Deleted",
  :copied => "Copied",
  :property_changed => "Property changed",
}

def changed_dirs_info(info, uri)
  rev = info.revision
  (info.added_dirs.collect do |dir|
     "  Added: #{dir}\n"
   end + info.deleted_dirs.collect do |dir|
     "  Deleted: #{dir}\n"
   end + info.updated_dirs.collect do |dir|
     "  Modified: #{dir}\n"
   end).join("\n")
end

def diff_info(info, uri)
  info.diffs.collect do |key, values|
    [
      key,
      values.collect do |type, value|
        case type
        when :added
          command = "cat"
          rev = "?revision=#{info.revision}&view=markup"
        when :modified, :property_changed
          command = "diff"
          rev = "?r1=#{info.revision}&r2=#{info.revision - 1}&diff_format=u"
        when :deleted, :copied
          command = "cat"
          rev = ""
        else
          raise "unknown diff type: #{value[:type]}"
        end

        link = [uri, key.sub(/ .+/,"")||""].join("/") + rev

        desc = ''

        [desc, link]
      end
    ]
  end
end

def make_header(to, from, info, params)
  headers = []
  headers << x_author(info)
  headers << x_repository(info)
  headers << x_revision(info)
  headers << x_id(info)
  headers << "Content-Type: text/plain; charset=us-ascii"
  headers << "Content-Transfer-Encoding: 7bit"
  headers << "From: #{from}"
  headers << "To: #{to.join(' ')}"
  headers << "Subject: #{make_subject(params[:name], info)}"
  headers.find_all do |header|
    /\A\s*\z/ !~ header
  end.join("\n")
end

def make_subject(name, info)
  branches = info.branches
  subject = ""
  subject << "#{info.author}:"
  subject << "r#{info.revision}"
  subject << " (#{branches.join(', ')})" unless branches.empty?
  subject << ": "
  subject << info.log.lstrip.lines.first.to_s.strip
  subject
end

def x_author(info)
  "X-SVN-Author: #{info.author}"
end

def x_repository(info)
  "X-SVN-Repository: XXX"
end

def x_id(info)
  "X-SVN-Commit-Id: #{info.entire_sha256}"
end

def x_revision(info)
  "X-SVN-Revision: #{info.revision}"
end

def make_mail(to, from, info, params)
  make_header(to, from, info, params) + "\n" + make_body(info, params)
end

def sendmail(to, from, mail)
  open("| #{SENDMAIL} #{to.join(' ')}", "w") do |f|
    f.print(mail)
  end
end

def output_rss(name, file, rss_uri, repos_uri, info)
  prev_rss = nil
  begin
    if File.exist?(file)
      File.open(file) do |f|
        prev_rss = RSS::Parser.parse(f)
      end
    end
  rescue RSS::Error
  end

  File.open(file, "w") do |f|
    f.print(make_rss(prev_rss, name, rss_uri, repos_uri, info).to_s)
  end
end

def make_rss(base_rss, name, rss_uri, repos_uri, info)
  RSS::Maker.make("1.0") do |maker|
    maker.encoding = "UTF-8"

    maker.channel.about = rss_uri
    maker.channel.title = rss_title(name || repos_uri)
    maker.channel.link = repos_uri
    maker.channel.description = rss_title(name || repos_uri)
    maker.channel.dc_date = info.date

    if base_rss
      base_rss.items.each do |item|
        item.setup_maker(maker)
      end
    end

    diff_info(info, repos_uri).each do |name, infos|
      infos.each do |desc, link|
        item = maker.items.new_item
        item.title = name
        item.description = desc
        item.content_encoded = "<pre>#{h(desc)}</pre>"
        item.link = link
        item.dc_date = info.date
        item.dc_creator = info.author
      end
    end

    maker.items.do_sort = true
    maker.items.max_size = 15
  end
end

def rss_title(name)
  "Repository of #{name}"
end

def rss_items(items, info, repos_uri)
  diff_info(info, repos_uri).each do |name, infos|
    infos.each do |desc, link|
      items << [link, name, desc, info.date]
    end
  end

  items.sort_by do |uri, title, desc, date|
    date
  end.reverse
end

def main(repo_path, to, rest)
  args, options = parse(rest)

  case options.vcs
  when "svn"
    require_relative "../lib/svn/info"
    infos = [
      Svn::Info.new(repo_path, args.first).tap do |info|
        info.log.sub!(/^([A-Z][a-z]{2} ){2}.*>\n/,"")
      end
    ]
  when "git"
    infos = args.each_slice(3).map do |oldrev, newrev, refname|
      p [oldrev, newrev, refname]
      GitInfoBuilder.new(repo_path).build(oldrev, newrev, refname)
    end
    require "pp"; pp infos
    abort "not implemented from here"
  else
    raise "unsupported vcs #{options.vcs.inspect} is specified"
  end

  params = {
    repository_uri: options.repository_uri,
    viewer_uri: options.viewer_uri,
    name: options.name
  }
  to = [to, *options.to]
  infos.each do |info|
    from = options.from || info.author_email
    sendmail(to, from, make_mail(to, from, info, params))

    if options.repository_uri and
        options.rss_path and
        options.rss_uri
      require "rss/1.0"
      require "rss/dublincore"
      require "rss/content"
      require "rss/maker"
      include RSS::Utils
      output_rss(options.name,
                 options.rss_path,
                 options.rss_uri,
                 options.repository_uri,
                 info)
    end
  end
end

repo_path, to, *rest = ARGV
begin
  main(repo_path, to, rest)
rescue StandardError => e
  $stderr.puts "#{e.class}: #{e.message}"
  $stderr.puts e.backtrace
  to = [to]
  from = ENV["USER"]
  begin
    _, options = parse(rest)
    to = options.error_to unless options.error_to.empty?
    from = options.from
  rescue StandardError
  end
  sendmail(to, from, <<-MAIL)
From: #{from}
To: #{to.join(', ')}
Subject: Error

#{$!.class}: #{$!.message}
#{$@.join("\n")}
MAIL
end
