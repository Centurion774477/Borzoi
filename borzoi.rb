# Borzoi
require 'json'
require 'async'
require_relative 'borzoi_cli'

puts 'hello, Borzoi!'

# essentially a lexer
class Sniffing
  def initialize
    @function_start_pattern = /^%bz/ # line starts with %bz
    @function_end_pattern = /bz%$/ # line ends with bz%
    @expression_end_pattern = /\;/
    @END = 'END'
  end
  
  def check_array(temporary_array, real_array)
    case real_array
    when empty?    then return  :empty_array
    when count > 0 then return :not_empty, real_array.count
    end
  end

  def sniffFunctionCalls(sniffing_file)
    found_these = []
    looking_for_end = false
    temp_bank = []

    raise 'Borzoi cannot find that file in this context!' unless File.exist?(sniffing_file)
    File.foreach(sniffing_file) do |line|
      if line =~ @function_start_pattern
        looking_for_end = true
        temp_bank << line until line =~ @function_end_pattern
      end
      if looking_for_end && line =~ @function_end_pattern
        found_these << temp_bank; found_these << @END # this is important for the Borzoi parser: it shows breaks between Borzoi statements
        temp_bank.clear 
      end
    end
    return found_these.reject (value) {value == @function_start_pattern} # incase any delimiters got mixed up in it
  end
end

foo = /(start)(.+?)(end)/ # after seeing an arrow grab arguments until bz%
bar = /([^,]+)/ # match any character until comma

puts 'ignore', foo
puts 'sorry', bar

# generate the .jsonl
class Scaffolding
  # there are two main files: map_bz.jsonl -> shows you what functions belong to what classes, good for quick validation;
  # the other -> functions_bz.json
  
  def initialize
    @MAP_FILE = 'map_bz.jsonl'.freeze
    @FUNCTIONS_FILE = 'functions_bz.json'.freeze
    @BOTH_FILES = [@MAP_FILE, @FUNCTIONS_FILE]
    # honestly, I changed my mind --Borzoi won't come with that many functions. I'll just let the users add their own things.
    @STARTING_MAP_DATA = [
      {:class => :motion, :children => [:newtons_second]},
      {:class => :energy, :children => [:einsteins_me_equivalence]}
    ]
    @STARTING_FUNCTIONS_DATA = [ 
      {:function => :einsteins_me_equivalence, :arity => 2, :arguments => [:energy, :mass]}.freeze,
      {:function => :newtons_second, :arity => 2, :arguments => [:mass, :acceleration]}.freeze
    ]
  end

  # create map_bz.jsonl
  def createMap
    File.open(@MAP_FILE, 'a') do |file|
      @STARTING_MAP_DATA.each do |function|
        file.puts(function.to_json)
      end
    end
  end

  # create functions_bz.json
  def createFunctions
    File.open(@FUNCTIONS_FILE, 'a') do |file|
      @STARTING_FUNCTIONS_DATA.each do |function|
        file.puts(function.to_json)
      end
    end
  end

  # returns true if both files exist; returns :missing_map or :missing_functions depending on whats missing.
  def checkFilePresence
    if File.exist?(@MAP_FILE) && File.exist?(@FUNCTIONS_FILE) then return true end
    return :missing_map if File.exist?(@FUNCTIONS_FILE)
    return :missing_functions if File.exist?(@MAP_FILE)
  end

  def scaffolder
    file_presence = checkFilePresence
    if file_presence == true then return true; end
    case file_presence
    when :missing_map       then return createMap
    when :missing_functions then return createFunctions
    end
  end
end

# so the user can add to Borzoi's bank of functions
class Appending
  def initialize
    @MAP_FILE = 'map_bz.jsonl'.freeze
    @FUNCTIONS_FILE = 'functions_bz.json'.freeze
    @EXISTING_CLASSES = [:motion, :energy]
    # I'm unsure if > are Regex characters so I escaped them anyways
    @APPEND_PATTERN = /([a-z]+)-([a-z]+)\|\>([a-z_]+)\|\>give-(\d)\|\>([a-z_]+(?:\s*,\s*[a-z_]+)*)/ # enroll-motion|>vel_time|>give-3|>init_vel, acceleration, speed;
    @AppendStruct = Struct.new(:creation, :class_name, :fn_name, :arity, :arguments)
    @append_message = '
      ======================================================================
      follow this structure to register a new function:
      write-class|>functionName|>pass-4|>foo, bar, qux, camel;
      explanation:
      write-class makes a new class (replace class with your name); the name of your function;
      pass the amount of arguments (arity), the names of your arguments.
      another example, but with adding to an existing class:
      enroll-motion|>vel_time|>give-3|>init_vel, acceleration, speed;
      ======================================================================
      (type abandon to exit)
      Your function:
      '
    @creating = false # as opposed to enrolling, which means to add a function to a vanilla class (motion or energy)
  end

  # Not so quick check over the append struct
  def checkAppend(all_matches)
    Async do
      func_data = File.read(@FUNCTIONS_FILE)
      parsed_func = JSON.parse(func_data)
      if parsed_func.include?(all_matches[3])
        fail "An existing function already exists: #{fn_name}" # it would be more useful if I gave the class name too
      end # this doesn't need a break, right?
    end

    Async do
      fail 'invalid class argument; only argue enroll or write' unless %w|enroll, write|.include?(all_matches[1])
      fail 'cannot enroll function to a non-existent class' unless all_matches[1] == 'enroll' && @EXISTING_CLASSES.include?(all_matches[2])
      fail 'invalid arity argument' unless all_matches[4].is_a?(Integer) && all_matches[4] < 9
    end
  end

  def normalAppend
    loop do
      puts @append_message
      input = gets.chomp; break if input == 'abandon'
      puts 'confirm message [y/N]', input
      input = gets.chomp; redo unless %w|y N|.include?(input)
      if input == 'N' then redo; else break end
    end

    input.match(@APPEND_PATTERN)
    # I wonder if I could have used a case for this, or atleast something more efficient
    @AppendStruct.creation = match[1]
    @AppendStruct.class_name = match[2]
    @AppendStruct.fn_name = match[3]
    @AppendStruct.arity = match[4]
    @AppendStruct.arguments = match[5..]
    checkAppend([match[1], match[2], match[3], match[4]])

    # so the input is supported, time to actually append it to the functions file
    
    # come back here; parse the matches, generate an AST, and append it to functions.
    File.open(@FUNCTIONS_FILE, 'a') do
      File.write({
        :fn_name => @AppendStruct.fn_name,
        :arity => @AppendStruct.arity,
        :arguments => [@AppendStruct.arguments]
      })
    end

    @creating = true if @AppendStruct.creation = 'write'
    if @creating then
      File.open(@MAP_FILE, 'a') do
        File.write({
          :class => @AppendStruct.class_name,
          :children => [@AppendStruct.fn_name] # for enrolling we would append to this
        })
      end
    return
    end
    raise 'An unexpected error occured' unless @AppendStruct.creation = 'enroll'

    File.open(@MAP_FILE, 'a') do |file|
      File.write(
        # I'm really not sure how to go about this but I have a solid idea of what I need to do:
        # I literally just need to call the dictionary and then :children and << appendage
        file[:children] << @AppendStruct.fn_name
      )
    end
    return
  end
  
  # note: this class can only be accessed through the CLI (borzoi_cli.rb)
  def append
    file_size = File.size(@FUNCTIONS_FILE)
    puts 'warning: your Borzoi Function file is almost too large.' if file_size in [1000..1996]
    if file_size > 1996 then fail "Borzoi refuses to append to your function file to due excessive size: #{file_size}" end
    normalAppend
  end
end


class Parsing
  def initialize
    @REGEX_PATTERNS = {
      :CLASS_FUNCTION_PERIOD => /([a-z_]+)(\.)([a-z_]+)/, # class.function
      :CLASS_FUNCTION_COLONS => /([a-z_]+)::([a-z_]+)/, # class::function
      :ARROW => /(->)/,
      :FUNCTION_START => /^%bz/,
      :FUNCTION_END => /bz%$/,
      :GIVE => /give/,

      :GIVE_BEFORE_DEFINE => /(give?)([a-z_]+)(\.)([a-z_]+)/, # give class.function foo
      :GIVE_BEFORE_DEFINE_B => /(give?)([a-z_]+)::([a-z_]+)/, # give class::function foo

      :GIVE_AFTER_DEFINE => /([a-z_]+)(\.)([a-z_]+)(give?)/, # class.function give foo
      :GIVE_AFTER_DEFINE_B => /([a-z_]+)::([a-z_]+)(give?)/, # class::function give foo

      :TRADITIONAL => /\A([a-z_]+)(\.)([a-z_]+)(\s*->\s*)([a-z_]+(?:\s*,\s*[a-z_]+)*)\z/, # class.function -> foo, bar
      :ARGUMENT_SORT_A => [/(->)(.+?)(bz%)/, /([^,]+)/] # class.function -> . . . --first part finds arguments, second filters them.
    }
    @traditional_lines = [] # class.function -> argument, another_argument
    @give_after_lines = [] # class.function give argument
    @give_before_lines = [] # give class.function argument
    @all_arrays = [@traditional_lines, @give_after_lines, @give_before_lines]
  end


  # class.function -> argument, another_argument
  def parseTraditional lines
    puts 'parse traditional'

    # first we need to find the actual class and then function they are calling.
    # find the class first to check what functions it owns, then check if the function is in it.
    lines.each do |line| # simply validating, but at a more precise scale this time
      line.match(@REGEX_PATTERNS[:TRADITIONAL])
      # this really shouldn't return nil since we checked it earlier
      clss_call = match[1]
      function = match[2]
      arguments = match[3..] # I don't know if the '..' is necessary
      # revisit after the datastructure is up
    end
  end

  def parseGiveAfter lines
    puts 'parse give after'
  end

  def parseGiveBefore lines
    puts 'parse give before'
  end


  # takes an array from Sniffing.sniffFunctionCalls
  def parseArray(array) 
    # since Borzoi is so dynamic with how you use it
    array.each do |function| # these lines are Borzoi, not just plain text
      case function
      when @REGEX_PATTERNS[:TRADITIONAL] then @traditional_lines << function # this doesn't mean it matches the exact syntax, just narrows it down.
      when @REGEX_PATTERNS[:GIVE_BEFORE_DEFINE], @REGEX_PATTERNS[:GIVE_BEFORE_DEFINE_B] then @give_before_lines << function
      when @REGEX_PATTERNS[:GIVE_AFTER_DEFINE], @REGEX_PATTERNS[:GIVE_AFTER_DEFINE_B] then @give_after_lines << function
      else fail 'syntaxError: invalid syntax detected in one of your Borzoi functions.'
      end
    end

    
    if @all_arrays.each {|array| array.empty?} then raise 'a critical error occured in the Borzoi Parser' end
    
    parseTraditional @traditional_lines unless @traditional_lines.empty?
    parseGiveAfter @give_after_lines    unless @give_after_lines.empty?
    parseGiveBefore @give_before_lines  unless @give_before_lines.empty?
  end
end


puts 'file for parsing:'
try_parse = gets.chomp

Sniff = Sniffing.new
returned_from_sniffer = Sniff.sniffFunctionCalls(try_parse)
if returned_from_sniffer.nil? then fail 'the file given to Borzoi does not contain any recognized Delimiters.' end

Parse = Parsing.new
Parse.parseArray(returned_from_sniffer)