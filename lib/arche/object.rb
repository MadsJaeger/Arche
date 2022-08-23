##
# Monkey patch of Object: includes Arche::Extensions::Nan, providing each object
# with the method :nan? always returning false, unless the class itself
# implements :nan?
class Object
  include Arche::Mixins::NaN
end
