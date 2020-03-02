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
    @compile_depth = 0
    @depth = 0

    @declarers = {}
  end

  def compile_mode
    @compile_depth.nonzero?
  end

  def run_token(token)
    #puts "#{' '*@depth} #{@compile_depth} #{token.name}"

    if compile_mode
      return compile(token)
    end
    if token.type == :literal || token.type == :number
      return @value_stack.push(token.name)
    end
    return if token.type == :comment
    return switch_to_compile! if declarer?(token)

    execute(token)
  end

  def ident_declarer?(token)
    @declarers.key?(token.name) && token.type == :ident
  end

  def declarer?(token)
    token.type == :declmark
  end

  def compile(token)
    @declarers[value_stack.first] = true if declarer?(token)
    switch_off_compile! if end_of_compile_unit?(token)
    switch_to_compile! if ident_declarer?(token)

    @compile_stack.push(token) if compile_mode
  end

  def end_of_compile_unit?(token)
    return false if token.type == :literal || token.type == :number

    token.name == 'です' || token.name == 'で'
  end

  def switch_to_compile!
    @compile_depth += 1
  end

  def switch_off_compile!
    @compile_depth -= 1

    name = @value_stack.pop
    @dictionary[name] = {
      type: :method,
      method: @compile_stack
    }
    @compile_stack = [] if @compile_depth == 0
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
      if numhash.key?(x)
        n += numhash[x]
      else
        n += x
      end
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

machine.dictionary['参考する'] = {
  type: :proc,
  proc: lambda do
    filename = machine.value_stack.pop
    s = File.read("#{filename}.uib")
    sc = Scanner.new(s)
    tk = Tokenizer.new(sc)

    loop do
      tok = tk.next_token
      break if tok.nil?

      machine.run_token(tok)
      # p machine.compile_stack
    end
  end
}

machine.dictionary['足す'] = {
  type: :proc,
  proc: lambda do
    thing2 = machine.value_stack.pop
    thing1 = machine.value_stack.pop
    machine.value_stack.push(thing1 + thing2)
  end
}

machine.dictionary['話題'] = {
  type: :proc,
  proc: lambda do
    machine.value_stack.push(machine.value_stack.first)
  end
}

machine.dictionary['の反対'] = {
  type: :proc,
  proc: lambda do
    machine.value_stack.push(machine.value_stack.first * -1)
  end
}

loop do
  token = tokenizer.next_token
  break if token.nil?

  machine.run_token(token)
  #p machine.value_stack
  #p machine.dictionary['0func']

rescue => e
  puts "誤り：#{e}"
  puts e.backtrace
  exit(1)
end

