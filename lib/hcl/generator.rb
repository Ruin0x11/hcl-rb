class HCL::Generator
  attr_reader :body, :doc

  def initialize(doc)
    # Ensure all the to_hcl methods are injected into the base Ruby classes
    # used by HCL.
    self.class.inject!

    @doc = doc
    @body = doc.to_hcl

    return @body
  end

  # Whether or not the injections have already been done.
  @@injected = false
  # Inject to_hcl methods into the Ruby classes used by HCL (booleans,
  # String, Numeric, Array). You can add to_hcl methods to your own classes
  # to allow them to be easily serialized by the generator (and it will shout
  # if something doesn't have a to_hcl method).
  def self.inject!
    return if @@injected
    require 'hcl/monkey_patch'
    @@injected = true
  end
end
