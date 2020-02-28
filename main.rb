# frozen_string_literal: true

require 'pry'

# A compilable token
class Token
  def initialize(raw)
    @raw = raw
  end

  def type
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
  end

  def run_token(token)
    return compile(token) if @compile_mode
    return @value_stack.push(token.name) if token.type == :literal
    return if token.type == :comment
    return switch_to_compile! if token.type == :declmark
    raise '見知らぬ名義' unless exists?(token)

    execute(token)
  end

  def compile(token)
    return switch_off_compile! if token.name == 'です' && token.type != :literal

    @compile_stack.push(token)
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
    entry = @dictionary[token.name]
    return entry[:proc].call if entry[:type] == :proc
    return execute_method(entry[:method]) if entry[:type] == :method
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
    /\s|　|を|と|、/.match(char).nil?
  end

  def rewind!
    @position = 0
  end

  def next_token
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

source = ARGF.read
scanner = Scanner.new(source)
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

loop do
  word = scanner.next_token
  break if word.nil?

  token = Token.new(word)
  machine.run_token(token)
end
