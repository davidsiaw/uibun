#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pry'

# A compilable token
class Token
  def initialize(raw)
    @raw = raw
  end

  def type
    return :number if @raw.is_a? Integer
    return :literal if @raw.start_with? '「'
    return :comment if @raw.start_with? '※'
    return :declmark if @raw.end_with? 'は'

    :ident
  end

  def name
    return @raw[1..-2] if type == :literal

    @raw
  end
end

# The machine
class Machine
  attr_accessor :dictionary, :value_stack, :compile_stack

  def initialize
    @dictionary = {}
    @value_stack = []
    @compile_stack = []
    @compile_mode = false

    @depth = 0
  end

  def run_token(token)
    #puts "#{' '*@depth} #{@compile_mode ? 1 : 0} #{token.name}"

    return compile(token) if @compile_mode
    if token.type == :literal || token.type == :number
      return @value_stack.push(token.name)
    end
    return if token.type == :comment
    return switch_to_compile! if token.type == :declmark

    execute(token)
  end

  def compile(token)
    return switch_off_compile! if end_of_compile_unit?(token)

    @compile_stack.push(token)
  end

  def end_of_compile_unit?(token)
    (token.name == 'です' || token.name == 'で') && token.type != :literal
  end

  def switch_to_compile!
    @compile_mode = true
  end

  def switch_off_compile!
    @compile_mode = false
    name = @value_stack.pop
    @dictionary[name] = {
      type: :method,
      method: @compile_stack
    }
    @compile_stack = []
  end

  def execute(token)
    raise "見知らぬ名義「#{token.name}」" unless exists?(token)
    @depth += 1
    entry = @dictionary[token.name]
    return entry[:proc].call if entry[:type] == :proc
    return execute_method(entry[:method]) if entry[:type] == :method
  ensure
    @depth -= 1
  end

  def execute_method(token_list)
    token_list.each do |token|
      run_token(token)
    end
  end

  def exists?(token)
    @dictionary.key?(token.name)
  end
end

# The scanner
class Scanner
  def initialize(source)
    @source = source
    rewind!
  end

  def space?(char)
    !notspace?(char)
  end

  def notspace?(char)
    /\s|　|を|と|、|に/.match(char).nil?
  end

  def rewind!
    @position = 0
  end

  def next_word
    consume_spaces!

    return nil if @position >= @source.length
    return literal if @source[@position] == '「'
    return comment if @source[@position] == '※'
    return declaration if @source[@position] == 'は'

    ident
  end

  def consume_spaces!
    # Move past spaces
    loop do
      break if notspace? @source[@position]
      break if @source[@position].nil?

      @position += 1
    end
  end

  def declaration
    @position += 1
    return 'とは' if @source[@position - 2] == 'と'

    'は'
  end

  def comment
    # Consume comment
    start_pos = @position
    @position += 1
    loop do
      break if @source[@position].nil?
      break if @source[@position] == '※'

      @position += 1
    end

    @position += 1
    @source[start_pos...@position]
  end

  def literal
    # Consume literal
    start_pos = @position
    loop do
      break if @source[@position].nil?
      break if @source[@position] == '」'

      @position += 1
    end

    @position += 1
    @source[start_pos...@position]
  end

  def ident
    # Consume token
    start_pos = @position
    loop do
      break if space? @source[@position]
      break if @source[@position].nil?

      @position += 1
    end

    @source[start_pos...@position]
  end
end

# Tokenizer
class Tokenizer
  def initialize(scanner)
    @scanner = scanner
  end

  def next_token
    word = @scanner.next_word
    return nil if word.nil?

    tokenize(word)
  end

  def numhash
    @numhash ||= begin
      nums = '０１２３４５６７８９'.split ''
      arr = nums.each_with_index.map { |x, i| [x, i.to_s] }
      arr += nums.each_with_index.map { |_, i| [i.to_s, i.to_s] }
      arr.to_h
    end
  end

  def number?(word)
    word =~ /\A-?[0-9０-９]+\Z/
  end

  def number(word)
    n = ''
    word.split('').each do |x|
      n += numhash[x]
    end

    n.to_i
  end

  def tokenize(word)
    return Token.new(number(word)) if number?(word)

    Token.new(word)
  end
end

source = ARGF.read
scanner = Scanner.new(source)
tokenizer = Tokenizer.new(scanner)
machine = Machine.new

machine.dictionary['書く'] = {
  type: :proc,
  proc: lambda do
    print machine.value_stack.pop
  end
}

machine.dictionary['改行する'] = {
  type: :proc,
  proc: lambda do
    puts
  end
}

machine.dictionary['改行ヲ書く'] = {
  type: :proc,
  proc: lambda do
    puts
  end
}

machine.dictionary['実行する'] = {
  type: :proc,
  proc: lambda do
    thing = machine.value_stack.pop
    machine.execute(Token.new(thing))
  end
}

machine.dictionary['残り'] = {
  type: :proc,
  proc: lambda do
    machine.value_stack.push(machine.value_stack.count)
  end
}

machine.dictionary['窟く'] = {
  type: :proc,
  proc: lambda do
    thing2 = machine.value_stack.pop
    thing1 = machine.value_stack.pop
    machine.value_stack.push(thing1.to_s + thing2.to_s)
  end
}

machine.dictionary['確認する'] = {
  type: :proc,
  proc: lambda do
    thing = machine.value_stack.pop
    if thing.zero?
      machine.value_stack.push(0)
    else
      machine.value_stack.push(1)
    end
  end
}

loop do
  token = tokenizer.next_token
  break if token.nil?

  machine.run_token(token)
rescue => e
  puts "誤り：#{e}"
  exit(1)
end
