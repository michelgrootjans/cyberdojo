
class KataController < ApplicationController

  def help
    @title = "Cyber Dojo : Kata Help"
    @manifest = 
    { 
      :visible_files =>  #TODO: make more realistic
      {        
        'unsplice.h' => { :preloaded => true, :content => 'void unsplice(char * line);' },
        'unsplice.c' => { :preloaded => true, :content => '#include "unsplice.h"' },
      },
      :font_family => 'monospace',
      :font_size => 14,
      :tab_size => 4,
    }
    @editable = true # needed to display toolbar in editArea    
  end

  def start
    @kata_id = params[:kata_id]
    @avatar = params[:avatar]
    @title = "Cyber Dojo : Kata " + @kata_id + ", " + @avatar
    kata = Kata.new(@kata_id)

    @manifest = load_starting_manifest(kata)
    run_tests_output = ""
    test_log = parse_run_tests_output(@manifest, run_tests_output.to_s)

    avatar = kata.avatar(@avatar)
    all_increments = []
    File.open(kata.folder, 'r') do |f|
      flock(f) do |lock|
        all_increments = avatar.read_most_recent(@manifest, test_log)
      end
    end
    
    @increments = limited(all_increments)
    @shown_increment_number = @increments.last[:number] + 1
    @outcome = @increments.last[:outcome].to_s
    @editable = true
  end

  def run_tests
    @kata_id = params[:kata_id]
    @avatar = params[:avatar]
    kata = Kata.new(@kata_id)
    avatar = kata.avatar(@avatar)
    @manifest = eval params['manifest.rb'] # load from web page
    # but reload max_run_tests_duration on each increment so it can be
    # altered by the sensei during the kata if necessary
    @manifest[:max_run_tests_duration] = kata.max_run_tests_duration
    @manifest[:visible_files].each { |filename,file| file[:content] = params[filename] } 

    new_filenames = params['visible_filenames_container'].strip.split(';')
    new_filenames.each do |new_filename|
      new_filename.strip!
      @manifest[:visible_files][new_filename] = {}
      @manifest[:visible_files][new_filename][:content] = params[new_filename]
    end

    all_increments = []
    File.open(kata.folder, 'r') do |f|
      flock(f) do |lock|
        @run_tests_output = do_run_tests(avatar.folder, kata.exercise.folder, @manifest)
        test_info = parse_run_tests_output(@manifest, @run_tests_output)
        test_info[:prediction] = params['run_tests_prediction']
        @outcome = test_info[:outcome].to_s
        all_increments = avatar.save(@manifest, test_info)
      end
    end

    @increments = limited(all_increments)
    @shown_increment_number = @increments.last[:number] + 1
    @editable = true
    respond_to do |format|
      format.js if request.xhr?
    end
  end

  #TODO: rename this is really a view of the dojo
  def see_all_increments
    @kata_id = params[:id]
    @title = "Cyber Dojo : Kata " + @kata_id + ", all increments"
    @avatars = {}
    kata = Kata.new(@kata_id)
    kata.avatars.each { |avatar| @avatars[avatar.name] = avatar.increments }
  end

  #TODO: this is really spying on another avatar-group
  def see_one_increment
    @kata_id = params[:id]
    @avatar = params[:avatar]
    increment_number = params[:increment]
    @title = "Cyber Dojo : Kata " + @kata_id + "," + @avatar + ", increment " + increment_number

    path = 'katas' + '/' + @kata_id + '/' + @avatar + '/' + increment_number + '/' + 'manifest.rb'
    @manifest = eval IO.read(path)

    kata = Kata.new(@kata_id)
    avatar = kata.avatar(@avatar)
    all_increments = avatar.increments
    one_increment = all_increments[increment_number.to_i]
    @increments = limited(all_increments)
    @outcome = one_increment[:outcome].to_s
    @shown_increment_number = one_increment[:number]
    @shown_increment_outcome = one_increment[:outcome]
    @editable = true # enables editArea toolbar - can't run-tests anyway
  end

private

  def load_starting_manifest(kata)
    catalogue = eval IO.read(kata.folder + '/' + 'kata_manifest.rb')
    manifest_folder = 'kata_catalogue' + '/' + catalogue[:language] + '/' + catalogue[:exercise]
    manifest = eval IO.read(manifest_folder + '/' + 'exercise_manifest.rb')
    manifest[:language] = catalogue[:language]
    manifest[:visible_files] = kata.exercise.visible_files    
	#TODO: control both from page and save back to manifest in each increment
    manifest[:font_size] = manifest[:font_size] || 14;
    manifest[:tab_size] = manifest[:tab_size ] ||  4;
    manifest[:font_family] = manifest[:font_family] || 'monospace';
    manifest
  end

  def limited(increments)
    max_increments_displayed = 25
    len = [increments.length, max_increments_displayed].min
    increments[-len,len]
  end

end

#=========================================================================

def do_run_tests(dst_folder, src_folder, manifest)
  # Save current files to sandbox
  sandbox = dst_folder + '/' + 'sandbox'
  system("rm -r #{sandbox}")
  make_dir(sandbox)
  manifest[:visible_files].each { |filename,file| save_file(sandbox, filename, file) }
  manifest[:hidden_files].each_key { |filename| system("cp #{src_folder}/#{filename} #{sandbox}") }

  # Run tests in sandbox in dedicated thread
  run_tests_output = []
  sandbox_thread = Thread.new do
    # o) run make, capturing stdout _and_ stderr    
    # o) popen runs its command as a subprocess
    # o) splitting and joining on "\n" should remove any operating 
    #    system differences regarding new-line conventions
    # TODO: run as a user with only execute rights; maybe using sudo -u, or qemu
    run_tests_output = IO.popen("cd #{sandbox}; ./kata.sh 2>&1").read.split("\n").join("\n")
  end
  # Build and run tests has limited time to complete
  max_seconds = manifest[:max_run_tests_duration]
  max_seconds.times do 
    sleep(1)
    break if sandbox_thread.status == false 
  end
  # If tests haven't finished after max_seconds assume 
  # they are stuck in an infinite loop and kill the thread
  if sandbox_thread.status != false 
    sandbox_thread.kill 
    run_tests_output = [ "run-tests stopped as it did not finish within #{max_seconds} seconds" ]
  end
  run_tests_output
end

def save_file(foldername, filename, file)
  path = foldername + '/' + filename
  # no need to lock when writing these files. They are write-once-only
  File.open(path, 'w') do |fd|
    filtered = makefile_filter(filename, file[:content])
    fd.write(filtered)
  end
  # .sh files (for example) need execute permissions
  File.chmod(file[:permissions], path) if file[:permissions]
end

# When editArea is used in the is_multi_files:true
# mode then the setting replace_tab_by_spaces: applies
# to ALL tabs (if set) or NONE of them (if not set).
# If it is not set then the default tab-width of the
# operating system seems to apply, which in Ubuntu
# is 8 spaces. There appears to be no way to alter the 
# tab-width in Ubuntu or in Firefox. Hence if you
# want tabs to expand to 4 spaces, as I do, you have to
# use replace_tab_by_spaces:=4 setting. This creates
# a problem for makefiles since they are tab sensitive.
# Hence this special filter, just for makefiles to 
# convert 4 leading spaces to a tab character. I don't
# use the manifest[:tab_size] setting for tab expansation
# since the makefile is only created in the sandbox; its
# not an individual file in the increment since its inside
# the manifest.
def makefile_filter(name, content)
  if name.downcase == 'makefile'
    lines = []
    newline = Regexp.new('[\r]?[\n]')
    content.split(newline).each do |line|
      line = "\t" + line[4 .. line.length-1] if line[0..3] == "    "
      lines.push(line)
    end
    content = lines.join("\n")
  end
  content
end

#=========================================================================

def parse_run_tests_output(manifest, output)
  so = output.to_s
  inc = eval "parse_#{manifest[:language]}_#{manifest[:unit_test_framework]}(so)"
  if Regexp.new("run-tests stopped").match(so)
    inc[:info] = so
    inc[:outcome] = :timeout
  else
    # put newlines into form that works in faked tool-tip
    inc[:info] = output.split("\n").join("<br/>")
  end
  inc
end

def parse_ruby_test_unit(output)
  ruby_pattern = Regexp.new('^(\d*) tests, (\d*) assertions, (\d*) failures, (\d*) errors')
  if match = ruby_pattern.match(output)
    if match[3] == "0" 
      inc = { :outcome => :passed }
    else
      inc = { :outcome => :failed }
    end
  else
    inc = { :outcome => :error }
  end
end

def parse_java_junit(output)
  junit_pass_pattern = Regexp.new('^OK \((\d*) test')
  if match = junit_pass_pattern.match(output)
    if match[1] != "0" 
      inc = { :outcome => :passed }
    else # treat zero passes as a fail
      inc = { :outcome => :failed }
    end
  else
    junit_fail_pattern = Regexp.new('^Tests run: (\d*),  Failures: (\d*)')
    if match = junit_fail_pattern.match(output)
      inc = { :outcome => :failed }
    else
      inc = { :outcome => :error }
    end
  end
end

def parse_cpp_assert(output)
  parse_c_assert(output)
end

def parse_c_assert(output)
  failed_pattern = Regexp.new('(.*)Assertion(.*)failed.')
  error_pattern = Regexp.new(':(\d*): error')
  if failed_pattern.match(output)
      inc = { :outcome => :failed }
  elsif error_pattern.match(output)
      inc = { :outcome => :error }
  else
      inc = { :outcome => :passed }
  end
end

def diff_time_to_s(past, now)
  days,hours,mins,secs = *dhms((now - past).to_i)
  return dhms_display(days,hours,mins,secs)
end

SECONDS_PER_MINUTE = 60
MINUTES_PER_HOUR = 60
HOURS_PER_DAY = 24

def dhms(value)
  seconds,value = mod_div(value, SECONDS_PER_MINUTE)
  minutes,value = mod_div(value, MINUTES_PER_HOUR)
    hours,days  = mod_div(value, HOURS_PER_DAY)
  [days, hours, minutes, seconds]
end

def mod_div(val, n)
  [val % n, val / n]
end

SEP = ":"

def dhms_display(days, hours, mins, secs)
  return  mins.to_s + SEP + lead_zero(secs)  if days == 0 and hours == 0
  return hours.to_s + SEP + lead_zero(mins)  + SEP + lead_zero(secs) if days == 0
  return  days.to_s + SEP + lead_zero(hours) + SEP + lead_zero(mins) + SEP + lead_zero(secs) 
end

def lead_zero(value)
  (value < 10 ? '0' : '') + value.to_s    
end


