require File.dirname(__FILE__) + '/../test_helper'
require 'Files'

class LanguageTests < ActionController::TestCase

  def language
  end
  
  test "name is as set" do
    language = make_language()    
    assert_equal 'Ruby-installed-and-working', language.name
  end
  
  test "dir is based on name" do
    language = make_language()
    assert_equal root_dir + '/languages/Ruby-installed-and-working', language.dir
  end
  
  test "blank opening line of visible starter file is retained" do
    language = make_language()
    lines = [ "", "def answer", "  42", "end" ]
    expected = lines.join("\n") + "\n"
    visible_files = language.visible_files
    assert_equal expected, visible_files['untitled.rb']
  end
  
  test "visible files are loaded but not output and not instructions" do
    language = make_language()    
    visible_files = language.visible_files
    assert_match visible_files['test_untitled.rb'], /^require '\.\/untitled'/ 
    assert_nil visible_files['output']
    assert_nil visible_files['instructions']
  end
  
  test "hidden filenames defaults to [ ] if not present" do
    language = make_language()
    assert_equal [ ], language.hidden_filenames    
  end
  
  test "unit test framework is loaded" do
    language = make_language()    
    assert_equal 'ruby_test_unit', language.unit_test_framework
  end
    
  test "tab is loaded when not defaulted" do
    language = make_language()    
    assert_equal 2, language.tab_size
  end
  
  def make_language()
    Language.new(root_dir, 'Ruby-installed-and-working')
  end
    
end
