require 'securerandom'
require 'set'
require 'dry-types'
# A module for implementing Java style interfaces in Ruby. For more information
# about Java interfaces, please see:
#
# http://java.sun.com/docs/books/tutorial/java/concepts/interface.html
#

# Top level module for RubyCube
module Cube
  module Interface
    # Exceptions thrown while checking interfaces
    class MethodMissing < RuntimeError; end
    class PrivateVisibleMethodMissing < MethodMissing; end
    class PublicVisibleMethodMissing < MethodMissing; end
    class MethodArityError < RuntimeError; end
    class TypeMismatchError < RuntimeError; end
    class InterfaceMatchError < RuntimeError; end

    alias :extends :extend

    private

    # convert a proc to lambda
    def convert_to_lambda &block
      obj = Object.new
      obj.define_singleton_method(:_, &block)
      return obj.method(:_).to_proc
    end

    def extend_object(obj)
      return append_features(obj) if Interface === obj
      append_features(class << obj; self end)
      included(obj)
    end

    # This is called before `included`
    def append_features(mod)
      return super if Interface === mod

      # Is this a sub-interface?
      # Get specs from super interfaces
      inherited = (self.ancestors-[self]).select{ |x| Interface === x }
      inherited_ids = inherited.map{ |x| x.instance_variable_get('@ids') }

      # Store required method ids
      specs = to_spec
      ids = @ids.keys + map_spec(inherited_ids.flatten).keys
      @unreq ||= []

      # Iterate over the methods, minus the unrequired methods, and raise
      # an error if the method has not been defined.
      mod_public_instance_methods = mod.public_instance_methods(true)
      (ids - @unreq).uniq.each do |id|
        id = id.to_s if RUBY_VERSION.to_f < 1.9
        unless mod_public_instance_methods.include?(id)
          raise Interface::PublicVisibleMethodMissing, "#{mod}: #{self}##{id}"
        end
        spec = specs[id]
        if spec.is_a?(Hash) && spec.key?(:in) && spec[:in].is_a?(Array)
          # Check arity and replace method with type checking method
          replace_check_method(mod, id, spec[:in], spec[:out])
        end
      end

      super mod
    end

    # Stash a method in the module for future checks
    def stash_method(mod, id)
      unless mod.instance_variable_defined?('@__interface_stashed_methods')
        mod.instance_variable_set('@__interface_stashed_methods', {})
      end
      mod.instance_variable_get('@__interface_stashed_methods')[id] = mod.instance_method(id)
    end

    # Get a stashed method for the module
    def stashed_method(mod, id)
      return nil unless mod.instance_variable_defined?('@__interface_stashed_methods')
      mod.instance_variable_get('@__interface_stashed_methods')[id]
    end

    # Check arity
    # Replace with type_checking method if demanded
    def replace_check_method(mod, id, inchecks, outcheck)
      # Get the previously stashed method if it exists
      stashed_meth = stashed_method(mod, id)
      orig_method = stashed_meth || mod.instance_method(id)
      unless mod.instance_variable_defined?("@__interface_arity_skip") \
        && mod.instance_variable_get("@__interface_arity_skip")
        orig_arity = orig_method.parameters.size
        check_arity = inchecks.size
        if orig_arity != check_arity
          raise Interface::MethodArityError,
                "#{mod}: #{self}##{id} arity mismatch: #{orig_arity} instead of #{check_arity}"
        end
      end

      # return if we are not doing runtime checks for this class
      unless ENV['RUBY_CUBE_TYPECHECK'].to_i > 0 \
        && mod.instance_variable_defined?("@__interface_runtime_check") \
        && mod.instance_variable_get("@__interface_runtime_check")
        return
      end
      # if the stashed method exists, it already exists. return
      return if stashed_meth
      iface = self
      stash_method(mod, id)
      # replace method with a type checking wrapper
      mod.class_exec do
        # random alias name to avoid conflicts
        ns_meth_name = "#{id}_#{SecureRandom.hex(3)}".to_sym
        alias_method ns_meth_name, id
        # The type checking wrapper
        define_method(id) do |*args|
          new_args = args.zip(inchecks).map do |v, t|
            begin
              Cube.check_type(t,v)
            rescue Dry::Types::ConstraintError => e
              raise Interface::TypeMismatchError,
                    "#{mod}: #{iface}##{id} : #{e.message}"
            end
          end
          # types look good, call the original method
          ret = send(ns_meth_name, *new_args)
          # check return type if it exists
          begin
            Cube.check_type(outcheck, ret) if outcheck
          rescue Dry::Types::ConstraintError => e
            raise Interface::TypeMismatchError,
                  "#{mod}: #{iface}##{id} (return): #{e.message}"
          end
          # looks good, return
          ret
        end
      end
    end

    # massage array spec and hash spec into hash spec
    def map_spec(ids)
      ids.reduce({}) do |res, m|
        if m.is_a?(Hash)
          res.merge(m)
        elsif m.is_a?(Symbol) || m.is_a?(String)
          res.merge({ m.to_sym => nil })
        end
      end
    end

    # validate the interface spec is valid
    def validate_spec(spec)
      [*spec].each do |t|
        unless t.is_a?(Dry::Types::Type) || t.is_a?(Module)
          raise ArgumentError, "#{t} is not a Dry::Types::Type nor a Module"
        end
      end
    end

    public

    # Accepts an array of method names that define the interface.  When this
    # module is included/implemented, those method names must have already been
    # defined.
    #
    def required_public_methods
      @ids.keys
    end

    def to_spec
      inherited = (self.ancestors-[self]).select{ |x| Interface === x }
      inherited_ids = inherited.map{ |x| x.instance_variable_get('@ids') }

      # Store required method ids
      inherited_specs = map_spec(inherited_ids.flatten)
      @ids.merge(inherited_specs)
    end

    def proto(meth, *args)
      out_spec = yield if block_given?
      validate_spec(args)
      validate_spec(out_spec) if out_spec
      @ids.merge!({ meth.to_sym => { in: args, out: out_spec } })
    end

    def public_visible(*ids)
      unless ids.all? { |id| id.is_a?(Symbol) || id.is_a?(String) }
        raise ArgumentError, "Arguments should be strings or symbols"
      end
      spec = map_spec(ids)
      @ids.merge!(spec)
    end

    def impotent
      cl = Cube.interface {}.extend(self)
      cl.module_exec do
        def extend_object(mod)
          super
        end
        def append_features(mod)
          super
        end
      end
      cl
    end

    # creates a shell object for testing
    def shell
      ids = @ids
      unreq = @unreq
      cls = Class.new(Object) do
        (ids.keys - unreq).each do |m|
          define_method(m) { |*args| }
        end
      end
      Cube[cls].send(:shell_implements, self)
    end
  end
end


