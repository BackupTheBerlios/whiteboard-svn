class Enum < Module
	class Member < Module
		attr_reader :enum, :index

		def initialize(enum, index, text)
			@enum, @index, @text = enum, index, text
			extend enum
		end

		alias :to_int :index
		alias :to_i :index

		def <=>(other)
			@index <=> other.index
		end

		def to_s() @text end

		include Comparable
	end

	def initialize(*symbols, &block)
		@members = []
		symbols.each_with_index do |symbol, index|
			text = symbol.to_s
			symbol = symbol.to_s.sub(/^[a-z]/) { |letter| letter.upcase }.to_sym
			member = Enum::Member.new(self, index, text)
			const_set(symbol, member)
			@members << member
		end
		super(&block)
	end

	def [](index) @members[index] end
	def size() @members.size end
	alias :length :size

	def first(*args) @members.first(*args) end
	def last(*args) @members.last(*args) end

	def each(&block) @members.each(&block) end
	include Enumerable
end
