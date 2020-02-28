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
  end

  def run_token(token)
    return @value_stack.push(token.name) if token.type == :literal
    return if token.type == :comment
    raise '見知らぬ名義' unless exists?(token)

    execute(token)
  end

  def execute(token)
    entry = @dictionary[token.name]
    return entry[:proc].call if entry[:type] == :proc

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
    # Move past spaces
    loop do
      break if notspace? @source[@position]
      break if @source[@position].nil?

      @position += 1
    end

    return nil if @position >= @source.length
    return literal if @source[@position] == '「'
    return comment if @source[@position] == '※'

    ident
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
    puts machine.value_stack.pop
  end
}

loop do
  word = scanner.next_token
  break if word.nil?

  token = Token.new(word)
  machine.run_token(token)
end
