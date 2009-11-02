require 'reek/name'
require 'reek/block_context'
require 'reek/object_refs'

class Array
  def power_set
    self.inject([[]]) { |cum, element| cum.cross(element) }
  end

  def bounded_power_set(lower_bound)
    power_set.select {|ps| ps.length > lower_bound}
  end

  def cross(element)
    result = []
    self.each do |set|
      result << set
      result << (set + [element])
    end
    result
  end

  def intersection
    self.inject { |res, elem| elem & res }
  end
end

module Reek

  module MethodParameters
    def self.is_arg?(param)
      return false if (Array === param and param[0] == :block)
      return !(param.to_s =~ /^\&/)
    end

    def names
      return @names if @names
      @names = self[1..-1].select {|arg| MethodParameters.is_arg?(arg)}.map {|arg| Name.new(arg)}
    end

    def length
      names.length
    end

    def include?(name)
      names.include?(name)
    end

    def to_s
      "[#{names.map{|nm| nm.to_s}.join(', ')}]"
    end
  end

  class MethodContext < VariableContainer
    attr_reader :parameters
    attr_reader :calls
    attr_reader :refs
    attr_reader :num_statements

    def initialize(outer, exp, record = true)
      super(outer, exp)
      @parameters = exp[exp[0] == :defn ? 2 : 3]  # SMELL: SimulatedPolymorphism
      @parameters ||= []
      @parameters.extend(MethodParameters)
      @name = Name.new(exp[1])
      @num_statements = 0
      @calls = Hash.new(0)
      @depends_on_self = false
      @refs = ObjectRefs.new
      @outer.record_method(self)
    end

    def count_statements(num)
      @num_statements += num
    end

    def depends_on_instance?
      @depends_on_self || is_overriding_method?(@name)
    end

    def has_parameter(sym)
      @parameters.include?(sym.to_s)
    end

    def record_call_to(exp)
      @calls[exp] += 1
      record_receiver(exp)
      check_for_attribute_declaration(exp)
    end

    def record_receiver(exp)
      receiver, meth = exp[1..2]
      receiver ||= [:self]
      case receiver[0]
      when :lvar
        @refs.record_ref(receiver) unless meth == :new
      when :self
        record_use_of_self
      end
    end

    def record_use_of_self
      record_depends_on_self
      @refs.record_reference_to_self
    end

    def record_instance_variable(sym)
      record_use_of_self
      @outer.record_instance_variable(sym)
    end
    
    def record_depends_on_self
      @depends_on_self = true
    end

    def outer_name
      "#{@outer.outer_name}#{@name}/"
    end

    def envious_receivers
      return [] if @refs.self_is_max?
      @refs.max_keys
    end

    def variable_names
      @parameters.names + @local_variables.to_a
    end
  end
end
