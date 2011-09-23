require File.expand_path('../../spec_helper', __FILE__)
require File.expand_path('../../fixtures/class', __FILE__)

ClassSpecsNumber = 12

module ClassSpecs
  Number = 12
end

describe "A class definition" do
  it "creates a new class" do
    ClassSpecs::A.should be_kind_of(Class)
    ClassSpecs::A.new.should be_kind_of(ClassSpecs::A)
  end

  it "has no class variables" do
    ClassSpecs::A.class_variables.should == []
  end

  it "raises TypeError if constant given as class name exists and is not a Module" do
    # 1.9 needs the constant defined here because of it's scoping rules
    ClassSpecsNumber = 12
    lambda {
      class ClassSpecsNumber
      end
    }.should raise_error(TypeError)
  end

  # test case known to be detecting bugs (JRuby, MRI 1.9)
  it "raises TypeError if the constant qualifying the class is nil" do
    lambda {
      class nil::Foo
      end
    }.should raise_error(TypeError)
  end

  it "raises TypeError if any constant qualifying the class is not a Module" do
    lambda {
      class ClassSpecs::Number::MyClass
      end
    }.should raise_error(TypeError)

    lambda {
      class ClassSpecsNumber::MyClass
      end
    }.should raise_error(TypeError)
  end

  it "allows using self as the superclass if self is a class" do
    ClassSpecs::I::J.superclass.should == ClassSpecs::I

    lambda {
      class ShouldNotWork < self; end
    }.should raise_error(TypeError)
  end

  it "raises a TypeError if inheriting from a metaclass" do
    obj = mock("metaclass super")
    meta = obj.singleton_class
    lambda { class ClassSpecs::MetaclassSuper < meta; end }.should raise_error(TypeError)
  end

#  # I do not think this is a valid spec   -- rue
#  it "has no class-level instance variables" do
#    ClassSpecs::A.instance_variables.should == []
#  end

  it "allows the declaration of class variables in the body" do
    ClassSpecs.string_class_variables(ClassSpecs::B).should == ["@@cvar"]
    ClassSpecs::B.send(:class_variable_get, :@@cvar).should == :cvar
  end

  it "stores instance variables defined in the class body in the class object" do
    ClassSpecs.string_instance_variables(ClassSpecs::B).should include("@ivar")
    ClassSpecs::B.instance_variable_get(:@ivar).should == :ivar
  end

  it "allows the declaration of class variables in a class method" do
    ClassSpecs::C.class_variables.should == []
    ClassSpecs::C.make_class_variable
    ClassSpecs.string_class_variables(ClassSpecs::C).should == ["@@cvar"]
  end

  it "allows the definition of class-level instance variables in a class method" do
    ClassSpecs.string_instance_variables(ClassSpecs::C).should_not include("@civ")
    ClassSpecs::C.make_class_instance_variable
    ClassSpecs.string_instance_variables(ClassSpecs::C).should include("@civ")
  end

  it "allows the declaration of class variables in an instance method" do
    ClassSpecs::D.class_variables.should == []
    ClassSpecs::D.new.make_class_variable
    ClassSpecs.string_class_variables(ClassSpecs::D).should == ["@@cvar"]
  end

  it "allows the definition of instance methods" do
    ClassSpecs::E.new.meth.should == :meth
  end

  it "allows the definition of class methods" do
    ClassSpecs::E.cmeth.should == :cmeth
  end

  it "allows the definition of class methods using class << self" do
    ClassSpecs::E.smeth.should == :smeth
  end

  it "allows the definition of Constants" do
    Object.const_defined?('CONSTANT').should == false
    ClassSpecs::E.const_defined?('CONSTANT').should == true
    ClassSpecs::E::CONSTANT.should == :constant!
  end

  it "returns the value of the last statement in the body" do
    class ClassSpecs::Empty; end.should == nil
    class ClassSpecs::Twenty; 20; end.should == 20
    class ClassSpecs::Plus; 10 + 20; end.should == 30
    class ClassSpecs::Singleton; class << self; :singleton; end; end.should == :singleton
  end
end

describe "An outer class definition" do
  ruby_version_is ""..."1.9" do
    it "contains the inner classes" do
      ClassSpecs::Container.constants.should include('A', 'B')
    end
  end

  ruby_version_is "1.9" do
    it "contains the inner classes" do
      ClassSpecs::Container.constants.should include(:A, :B)
    end
  end
end

describe "A class definition extending an object (sclass)" do
  it "allows adding methods" do
    ClassSpecs::O.smeth.should == :smeth
  end

  it "raises a TypeError when trying to extend numbers" do
    lambda {
      eval <<-CODE
        class << 1
          def xyz
            self
          end
        end
      CODE
    }.should raise_error(TypeError)
  end

  it "allows accessing the block of the original scope" do
    ClassSpecs.sclass_with_block { 123 }.should == 123
  end

  not_compliant_on :rubinius do
    it "can use return to cause the enclosing method to return" do
      ClassSpecs.sclass_with_return.should == :inner
    end
  end
end

describe "Reopening a class" do
  it "extends the previous definitions" do
    c = ClassSpecs::F.new
    c.meth.should == :meth
    c.another.should == :another
  end

  it "overwrites existing methods" do
    ClassSpecs::G.new.override.should == :override
  end

  it "raises a TypeError when superclasses mismatch" do
    lambda { class ClassSpecs::A < Array; end }.should raise_error(TypeError)
  end

  it "adds new methods to subclasses" do
    lambda { ClassSpecs::M.m }.should raise_error(NoMethodError)
    class ClassSpecs::L
      def self.m
        1
      end
    end
    ClassSpecs::M.m.should == 1
  end
end

describe "class provides hooks" do
  it "calls inherited when a class is created" do
    ClassSpecs::H.track_inherited.should == [ClassSpecs::K]
  end
end

describe "An anonymous class" do
  it "takes on the name of the first constant it is assigned to" do
    c1 = Class.new
    c1.inspect.should =~ /#<Class/
    ClassSpecs::AnonymousClasses::C1 = c1
    c1.inspect.should == "ClassSpecs::AnonymousClasses::C1"
    
    c2 = Class.new
    ClassSpecs::AnonymousClasses.const_set :C2, c2
    c2.inspect.should == "ClassSpecs::AnonymousClasses::C2"
  end
  
  it "forces named nested classes to be anonymous" do
    c3 = Class.new
    c3.const_set :C4, Class.new
    
    c3::C4.inspect.should =~ /#<Class/
    
    ClassSpecs::AnonymousClasses::C3 = c3
    c3::C4.inspect.should == "ClassSpecs::AnonymousClasses::C3::C4"

    c5 = Class.new
    c5.const_set :C6, Class.new

    ClassSpecs::AnonymousClasses.const_set :C5, c5
    c5::C6.inspect.should == "ClassSpecs::AnonymousClasses::C5::C6"
  end
  
  it "never recalculates full name once no longer anonymous" do
    c6 = Class.new
    c6.const_set :C7, Class.new    
    ClassSpecs::AnonymousClasses::C6 = c6
    c6::C7.inspect.should == "ClassSpecs::AnonymousClasses::C6::C7"
    
    ClassSpecs::AnonymousClasses::C8 = c6::C7
    ClassSpecs::AnonymousClasses::C8.inspect.should == "ClassSpecs::AnonymousClasses::C6::C7"
  end
end
