require "fileutils"
require "svn/info"

# Usage:
#   $ gem install test-unit
#   $ ruby -Ilib -rtest/unit test/test_info.rb

class InfoTest < Test::Unit::TestCase

  include Svn

  def initialize(*args, &block)
    super
    @repos = "test/repos"
    @repos_orig = "#{@repos}.orig"
    @wc = "test/wc"
    @wc_orig = "#{@wc}.orig"
    @rev = 0
  end

  def setup
    setup_repos
    setup_wc
  end

  def setup_repos
    unless File.exist?(@repos_orig)
      `svnadmin create #{@repos_orig}`
    end
    FileUtils.cp_r(@repos_orig, @repos, {:preserve => true})
  end

  def setup_wc
    unless File.exist?(@wc_orig)
      `svn co file://#{Dir.pwd}/#{@repos} #{@wc_orig}`
    end
    FileUtils.cp_r(@wc_orig, @wc, {:preserve => true})
  end

  def teardown
    FileUtils.rm_rf([@repos, @wc])
  end

  def test_info
    file = "hello.txt"
    log = "test commit\nnew line"
    FileUtils.touch("#{@wc}/#{file}")
    `svn add #{@wc}/#{file}`
    commit(log)

    info = make_info
    assert_equal(ENV["USER"], info.author)
    assert_instance_of(Time, info.date)
    assert_equal(@rev, info.revision)
    assert_equal(log, info.log)
  end

  def test_dirs_changed
    file = "new.txt"
    dir = "new_dir/"
    log = "add dir"
    `svn mkdir #{@wc}/#{dir}`
    FileUtils.touch("#{@wc}/#{dir}#{file}")
    `svn add #{@wc}/#{dir}#{file}`
    commit(log)

    info = make_info
    assert_equal(["/", dir], info.changed_dirs)
    assert_equal(@rev, info.revision)
    assert_equal(log, info.log)
  end

  def test_changed
    dir = "changed_dir/"
    tmp_dir = "changed_tmp_dir/"
    `svn mkdir #{@wc}/#{dir}`
    `svn mkdir #{@wc}/#{tmp_dir}`

    file1 = "changed1.txt"
    file2 = "#{dir}changed2.txt"
    file3 = "changed3.txt"
    file4 = "#{dir}changed4.txt"
    file5 = "changed5.txt"
    log = "added 2 new files"
    FileUtils.touch("#{@wc}/#{file1}")
    FileUtils.touch("#{@wc}/#{file2}")
    FileUtils.touch("#{@wc}/#{file3}")
    FileUtils.touch("#{@wc}/#{file4}")
    FileUtils.touch("#{@wc}/#{file5}")
    `svn add #{@wc}/#{file1}`
    `svn add #{@wc}/#{file2}`
    `svn add #{@wc}/#{file3}`
    `svn add #{@wc}/#{file4}`
    `svn add #{@wc}/#{file5}`
    commit(log)

    info = make_info
    assert_equal([].sort, info.updated_dirs.sort)
    assert_equal([].sort, info.deleted_dirs.sort)
    assert_equal([dir, tmp_dir].sort, info.added_dirs.sort)

    file6 = "#{dir}changed6.txt"
    file7 = "changed7.txt"
    file8 = "#{dir}changed8.txt"
    log = "changed 3 files\ndeleted 2 files\nadded 3 files"
    File.open("#{@wc}/#{file1}", "w") {|f| f.puts "changed"}
    File.open("#{@wc}/#{file2}", "w") {|f| f.puts "changed"}
    File.open("#{@wc}/#{file3}", "w") {|f| f.puts "changed"}
    `svn rm --force #{@wc}/#{file4}`
    `svn rm --force #{@wc}/#{file5}`
    FileUtils.touch("#{@wc}/#{file6}")
    FileUtils.touch("#{@wc}/#{file7}")
    FileUtils.touch("#{@wc}/#{file8}")
    `svn add #{@wc}/#{file6}`
    `svn add #{@wc}/#{file7}`
    `svn add #{@wc}/#{file8}`
    `svn rm #{@wc}/#{tmp_dir}`
    commit(log)

    info = make_info
    assert_equal([file1, file2, file3].sort, info.updated_files.sort)
    assert_equal([file4, file5].sort, info.deleted_files.sort)
    assert_equal([file6, file7, file8].sort, info.added_files.sort)
    assert_equal([].sort, info.updated_dirs.sort)
    assert_equal([tmp_dir].sort, info.deleted_dirs.sort)
    assert_equal([].sort, info.added_dirs.sort)
    assert_equal(@rev, info.revision)
    assert_equal(log, info.log)
  end

  def test_diff
    log = "diff"

    file1 = "diff1.txt"
    file2 = "diff2.txt"
    file3 = "diff3.txt"
    FileUtils.touch("#{@wc}/#{file1}")
    File.open("#{@wc}/#{file2}", "w") {|f| f.puts "changed"}
    FileUtils.touch("#{@wc}/#{file3}")
    `svn add #{@wc}/#{file1}`
    `svn add #{@wc}/#{file2}`
    `svn add #{@wc}/#{file3}`
    `svn propset AAA BBB #{@wc}/#{file1}`
    commit(log)

    file4 = "diff4.txt"
    file5 = "diff5.txt"
    File.open("#{@wc}/#{file1}", "w") {|f| f.puts "changed"}
    File.open("#{@wc}/#{file2}", "w") {|f| f.puts "removed\nadded"}
    FileUtils.touch("#{@wc}/#{file4}")
    `svn add #{@wc}/#{file4}`
    `svn propdel AAA #{@wc}/#{file1}`
    `svn propset XXX YYY #{@wc}/#{file4}`
    `svn copy #{@wc}/#{file3} #{@wc}/#{file5}`
    commit(log)
    
    info = make_info
    keys = info.diffs.keys.sort
    file5_key = keys.last
    # assert_equal(4, info.diffs.size)
    # assert_equal([file1, file2, file4].sort, keys[0..-2])
    assert_match(/\A#{file5}/, file5_key)
    assert(info.diffs[file1].has_key?(:modified))
    assert(info.diffs[file2].has_key?(:modified))
    # assert(info.diffs[file4].has_key?(:added))
    assert(info.diffs[file4].has_key?(:property_changed))
    assert(info.diffs[file5_key].has_key?(:copied))
    assert_equal(1, info.diffs[file1][:modified][:added])
    assert_equal(0, info.diffs[file1][:modified][:deleted])
    # assert_equal(2, info.diffs[file2][:modified][:added])
    # assert_equal(1, info.diffs[file2][:modified][:deleted])
    # assert_equal(0, info.diffs[file4][:added][:added])
    # assert_equal(0, info.diffs[file4][:added][:deleted])
    assert_equal(0, info.diffs[file5_key][:copied][:added])
    assert_equal(0, info.diffs[file5_key][:copied][:deleted])
    assert_equal(@rev, info.revision)
    assert_equal(log, info.log)
  end

  def test_sha256
    log = "sha256"
    
    file1 = "diff1.txt"
    file2 = "diff2.txt"
    file3 = "diff3.txt"
    file1_content = "added file1"
    file2_content = "added file2"
    file3_content = "added file3"
    all_content = file1_content + file2_content + file3_content
    File.open("#{@wc}/#{file1}", "w") {|f| f.print file1_content}
    File.open("#{@wc}/#{file2}", "w") {|f| f.print file2_content}
    File.open("#{@wc}/#{file3}", "w") {|f| f.print file3_content}
    `svn add #{@wc}/#{file1}`
    `svn add #{@wc}/#{file2}`
    `svn add #{@wc}/#{file3}`
    commit(log)

    info = make_info
    assert_equal(3, info.sha256.size)
    assert_equal(Digest::SHA256.hexdigest(file1_content),
                 info.sha256[file1][:sha256])
    assert_equal(Digest::SHA256.hexdigest(file2_content),
                 info.sha256[file2][:sha256])
    assert_equal(Digest::SHA256.hexdigest(file3_content),
                 info.sha256[file3][:sha256])
    assert_equal(Digest::SHA256.hexdigest(all_content),
                 info.entire_sha256)
    assert_equal(@rev, info.revision)
    assert_equal(log, info.log)
  end
  
  def commit(log)
    `svn commit #{@wc} -m "#{log}"`
    @rev += 1
  end
  
  def make_info
    Info.new("#{Dir.pwd}/#{@repos}", @rev)
  end

end
